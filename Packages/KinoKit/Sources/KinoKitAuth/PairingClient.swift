import Foundation
import KinoKitCore
import KinoKitGenerated
import KinoKitTransport
import os

protocol PairingPoller: Sendable {
  func requestCode(deviceName: String, platform: ClientPlatform) async throws -> PairingChallenge
  func poll(code: String) async throws -> PairingPollResult
}

enum PairingPollResult: Sendable, Equatable {
  case pending
  case approved(token: String, tokenID: UUID, userID: UUID)
  case rejected
  case expired
}

/// Client-side pairing flow helper for requesting and awaiting server approval.
public struct PairingClient: Sendable {
  private let server: ResolvedServer
  private let poller: any PairingPoller
  private let clock: any Clock<Duration>
  private let jitter: @Sendable () -> Duration
  private let logger = Logger(subsystem: "kino.kit", category: "pairing")

  /// Creates a pairing client backed by a live generated HTTP transport.
  public init(
    server: ResolvedServer,
    clock: any Clock<Duration> = ContinuousClock(),
    jitter: @escaping @Sendable () -> Duration = {
      .milliseconds(Int.random(in: -500...500))
    }
  ) {
    self.init(
      server: server,
      transport: .live(baseURL: server.baseURL, token: { nil }),
      clock: clock,
      jitter: jitter
    )
  }

  /// Creates a pairing client backed by the provided transport.
  public init(
    server: ResolvedServer,
    transport: KinoTransport,
    clock: any Clock<Duration> = ContinuousClock(),
    jitter: @escaping @Sendable () -> Duration = {
      .milliseconds(Int.random(in: -500...500))
    }
  ) {
    self.server = server
    self.poller = LivePairingPoller(transport: transport)
    self.clock = clock
    self.jitter = jitter
  }

  init(
    server: ResolvedServer,
    poller: any PairingPoller,
    clock: any Clock<Duration>,
    jitter: @escaping @Sendable () -> Duration = { .zero }
  ) {
    self.server = server
    self.poller = poller
    self.clock = clock
    self.jitter = jitter
  }

  /// Requests a short pairing code for this device.
  public func requestCode(deviceName: String, platform: ClientPlatform) async throws
    -> PairingChallenge
  {
    try await poller.requestCode(deviceName: deviceName, platform: platform)
  }

  /// Polls until the pairing is approved, rejected, or expired.
  public func awaitApproval(_ challenge: PairingChallenge) async throws -> AuthorizedSession {
    while Date() < challenge.expiresAt {
      do {
        switch try await poller.poll(code: challenge.code) {
        case .pending:
          logger.debug("Pairing approval still pending")
          try await clock.sleep(for: .seconds(2) + jitter())
        case .approved(let token, let tokenID, let userID):
          logger.debug("Pairing approval received")
          return AuthorizedSession(
            serverInstanceID: server.instanceID,
            baseURL: server.baseURL,
            tokenID: tokenID,
            token: token,
            userID: userID,
            deviceName: challenge.deviceName,
            createdAt: Date()
          )
        case .rejected:
          logger.debug("Pairing approval rejected")
          throw PairingError.rejected
        case .expired:
          logger.debug("Pairing approval expired")
          throw PairingError.expired
        }
      } catch let error as PairingError {
        throw error
      } catch {
        logger.error("Pairing approval failed")
        throw error
      }
    }
    logger.debug("Pairing challenge expired before approval")
    throw PairingError.expired
  }
}

private struct LivePairingPoller: PairingPoller {
  let transport: KinoTransport

  func requestCode(deviceName: String, platform: ClientPlatform) async throws -> PairingChallenge {
    do {
      let output = try await transport.makeClient().createPairing(
        body: .json(
          .init(
            deviceName: deviceName,
            platform: platform.generatedPairingPlatform
          )
        )
      )

      switch output {
      case .created(let response):
        let body = try response.body.json
        guard let pairingID = UUID(uuidString: body.pairingId) else {
          throw PairingError.malformedResponse
        }
        return PairingChallenge(
          pairingID: pairingID,
          code: body.code,
          expiresAt: body.expiresAt,
          deviceName: deviceName
        )
      case .badRequest:
        throw PairingError.malformedResponse
      case .internalServerError:
        throw KinoError.server(status: 500, body: nil)
      case .undocumented(let statusCode, _):
        if statusCode == 409 {
          throw PairingError.codeCollision
        }
        throw KinoError.server(status: statusCode, body: nil)
      }
    } catch let error as PairingError {
      throw error
    } catch let error as KinoError {
      throw error
    } catch is DecodingError {
      throw PairingError.malformedResponse
    } catch let error as URLError {
      throw KinoError.transport(error)
    } catch {
      // Preserve the original error so failures are debuggable instead of
      // being masked as URLError(.badServerResponse).
      throw KinoError.decoding(error)
    }
  }

  func poll(code: String) async throws -> PairingPollResult {
    do {
      let output = try await transport.makeClient().getPairing(
        path: .init(code: code)
      )

      switch output {
      case .ok(let response):
        let body = try response.body.json
        switch body {
        case .case1:
          return .pending
        case .case2(let payload):
          guard
            let tokenID = UUID(uuidString: payload.tokenId),
            let userID = UUID(uuidString: payload.userId)
          else {
            throw PairingError.malformedResponse
          }
          return .approved(
            token: payload.token,
            tokenID: tokenID,
            userID: userID
          )
        }
      case .notFound:
        return .rejected
      case .gone:
        return .expired
      case .internalServerError:
        throw KinoError.server(status: 500, body: nil)
      case .undocumented(let statusCode, _):
        throw KinoError.server(status: statusCode, body: nil)
      }
    } catch let error as PairingError {
      throw error
    } catch let error as KinoError {
      throw error
    } catch is DecodingError {
      throw PairingError.malformedResponse
    } catch let error as URLError {
      throw KinoError.transport(error)
    } catch {
      // Preserve the original error so failures are debuggable instead of
      // being masked as URLError(.badServerResponse).
      throw KinoError.decoding(error)
    }
  }
}

extension ResolvedServer {
  fileprivate var baseURL: URL {
    var components = URLComponents()
    components.scheme = "http"
    components.host = host
    components.port = port
    return components.url ?? URL(string: "http://\(host):\(port)")!
  }
}

extension ClientPlatform {
  fileprivate var generatedPairingPlatform: Components.Schemas.PairingPlatform {
    switch self {
    case .iOS:
      return .ios
    case .tvOS:
      return .tvos
    case .macOS:
      return .macos
    }
  }
}
