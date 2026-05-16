import Foundation
import KinoKitCore
import XCTest

@testable import KinoKitAuth

final class PairingClientTests: XCTestCase {
  func test_pairingChallengeCodableRoundTrip() throws {
    let challenge = PairingChallenge(
      pairingID: UUID(),
      code: "123456",
      expiresAt: Date(timeIntervalSince1970: 1_800_000_000),
      deviceName: "Test Device"
    )

    let data = try JSONEncoder().encode(challenge)
    let decoded = try JSONDecoder().decode(PairingChallenge.self, from: data)

    XCTAssertEqual(decoded, challenge)
  }

  func test_awaitApprovalPollsUntilApproved() async throws {
    let tokenID = UUID()
    let userID = UUID()
    let clock = ImmediateTestClock()
    let poller = FakePairingPoller(
      requestResult: .success(challenge()),
      pollSteps: [
        .result(.pending),
        .result(.pending),
        .result(.approved(token: "token", tokenID: tokenID, userID: userID)),
      ]
    )
    let client = PairingClient(
      server: server(),
      poller: poller,
      clock: clock,
      jitter: { .zero }
    )

    let session = try await client.awaitApproval(challenge())

    XCTAssertEqual(session.token, "token")
    XCTAssertEqual(session.tokenID, tokenID)
    XCTAssertEqual(session.userID, userID)
    let polledCodes = await poller.polledCodes
    XCTAssertEqual(polledCodes, ["123456", "123456", "123456"])
    XCTAssertEqual(clock.sleepDurations, [.seconds(2), .seconds(2)])
  }

  func test_awaitApprovalThrowsExpiredWithoutPollingPastWallClockExpiry() async throws {
    let poller = FakePairingPoller(
      requestResult: .success(challenge()),
      pollSteps: [.result(.approved(token: "token", tokenID: UUID(), userID: UUID()))]
    )
    let client = PairingClient(
      server: server(),
      poller: poller,
      clock: ImmediateTestClock()
    )

    try await assertPairingError(.expired) {
      _ = try await client.awaitApproval(challenge(expiresAt: Date().addingTimeInterval(-1)))
    }
    let polledCodes = await poller.polledCodes
    XCTAssertEqual(polledCodes, [])
  }

  func test_awaitApprovalThrowsRejected() async throws {
    let client = PairingClient(
      server: server(),
      poller: FakePairingPoller(
        requestResult: .success(challenge()),
        pollSteps: [.result(.rejected)]
      ),
      clock: ImmediateTestClock()
    )

    try await assertPairingError(.rejected) {
      _ = try await client.awaitApproval(challenge())
    }
  }

  func test_requestCodeSurfacesCodeCollision() async throws {
    let client = PairingClient(
      server: server(),
      poller: FakePairingPoller(
        requestResult: .failure(PairingError.codeCollision),
        pollSteps: []
      ),
      clock: ImmediateTestClock()
    )

    try await assertPairingError(.codeCollision) {
      _ = try await client.requestCode(deviceName: "Test Mac", platform: .macOS)
    }
  }

  func test_awaitApprovalSurfacesMalformedResponse() async throws {
    let client = PairingClient(
      server: server(),
      poller: FakePairingPoller(
        requestResult: .success(challenge()),
        pollSteps: [.failure(PairingError.malformedResponse)]
      ),
      clock: ImmediateTestClock()
    )

    try await assertPairingError(.malformedResponse) {
      _ = try await client.awaitApproval(challenge())
    }
  }

  func test_awaitApprovalRejectsReplayAfterTokenConsumed() async throws {
    let client = PairingClient(
      server: server(),
      poller: FakePairingPoller(
        requestResult: .success(challenge()),
        pollSteps: [.result(.expired)]
      ),
      clock: ImmediateTestClock()
    )

    try await assertPairingError(.expired) {
      _ = try await client.awaitApproval(challenge())
    }
  }
}

private actor FakePairingPoller: PairingPoller {
  private let requestResult: Result<PairingChallenge, any Error>
  private var pollSteps: [PollStep]
  private var codes: [String] = []

  init(requestResult: Result<PairingChallenge, any Error>, pollSteps: [PollStep]) {
    self.requestResult = requestResult
    self.pollSteps = pollSteps
  }

  var polledCodes: [String] {
    codes
  }

  func requestCode(deviceName: String, platform: ClientPlatform) async throws -> PairingChallenge {
    try requestResult.get()
  }

  func poll(code: String) async throws -> PairingPollResult {
    codes.append(code)
    guard !pollSteps.isEmpty else {
      return .pending
    }

    switch pollSteps.removeFirst() {
    case .result(let result):
      return result
    case .failure(let error):
      throw error
    }
  }
}

private enum PollStep: Sendable {
  case result(PairingPollResult)
  case failure(any Error)
}

private final class ImmediateTestClock: Clock, @unchecked Sendable {
  typealias Instant = TestInstant

  private let lock = NSLock()
  private var current = TestInstant(offset: .zero)
  private var sleeps: [Duration] = []

  var now: TestInstant {
    lock.withLock { current }
  }

  var minimumResolution: Duration {
    .zero
  }

  var sleepDurations: [Duration] {
    lock.withLock { sleeps }
  }

  func sleep(until deadline: TestInstant, tolerance: Duration?) async throws {
    try Task.checkCancellation()
    lock.withLock {
      sleeps.append(current.duration(to: deadline))
      current = deadline
    }
  }
}

private struct TestInstant: InstantProtocol {
  let offset: Duration

  func advanced(by duration: Duration) -> TestInstant {
    TestInstant(offset: offset + duration)
  }

  func duration(to other: TestInstant) -> Duration {
    other.offset - offset
  }

  static func < (lhs: TestInstant, rhs: TestInstant) -> Bool {
    lhs.offset < rhs.offset
  }
}

private func assertPairingError(
  _ expected: PairingError,
  operation: () async throws -> Void
) async throws {
  do {
    try await operation()
    XCTFail("Expected PairingError.\(expected)")
  } catch let error as PairingError {
    XCTAssertEqual(String(describing: error), String(describing: expected))
  }
}

private func server() -> ResolvedServer {
  ResolvedServer(
    instanceID: UUID(),
    host: "127.0.0.1",
    port: 3000,
    apiVersion: "v1",
    serverVersion: "0.1.0"
  )
}

private func challenge(expiresAt: Date = Date().addingTimeInterval(60)) -> PairingChallenge {
  PairingChallenge(
    pairingID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    code: "123456",
    expiresAt: expiresAt,
    deviceName: "Living Room"
  )
}
