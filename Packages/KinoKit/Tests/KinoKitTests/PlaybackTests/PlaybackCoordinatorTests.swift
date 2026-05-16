import Foundation
import XCTest

@testable import KinoKit

final class PlaybackCoordinatorTests: XCTestCase {
  func test_prepareReturnsVariantChooserPlan() async throws {
    let item = Self.item(outputs: [Self.output(id: 1, codec: .h264, height: 1080)])
    let capabilities = Self.caps(codecs: [.h264], maxHeight: 1080)
    let coordinator = PlaybackCoordinator(
      reporter: FakeReporter(), item: item, capabilities: capabilities)

    let plan = try await coordinator.prepare()

    XCTAssertEqual(
      plan.source,
      .hlsTranscodeOutput(masterURL: Self.outputURL(1), outputID: Self.id(1))
    )
  }

  func test_handlePlayerFailureFallsBackFromHlsOutputToLive() async throws {
    let item = Self.item(
      outputs: [Self.output(id: 2, codec: .h264, height: 1080)],
      sources: [Self.source(codec: .hevc, height: 2160)]
    )
    let coordinator = PlaybackCoordinator(
      reporter: FakeReporter(),
      item: item,
      capabilities: Self.caps(codecs: [.h264], maxHeight: 1080)
    )

    _ = try await coordinator.prepare()
    let fallback = try await coordinator.handlePlayerFailure(TestError.failure)

    XCTAssertEqual(
      fallback.source,
      .hlsLive(
        masterURL: Self.liveURL(sourceID: Self.id(100), profile: "h264-1080p"),
        profile: "h264-1080p")
    )
  }

  func test_handlePlayerFailureFallsBackFromDirectToCachedHlsWhenOutputExists() async throws {
    let item = Self.item(
      outputs: [Self.output(id: 3, codec: .av1, height: 2160)],
      sources: [Self.source(codec: .h264, height: 1080)]
    )
    let coordinator = PlaybackCoordinator(
      reporter: FakeReporter(),
      item: item,
      capabilities: Self.caps(codecs: [.h264], maxHeight: 1080)
    )

    _ = try await coordinator.prepare()
    let fallback = try await coordinator.handlePlayerFailure(TestError.failure)

    XCTAssertEqual(
      fallback.source,
      .hlsTranscodeOutput(masterURL: Self.outputURL(3), outputID: Self.id(3))
    )
  }

  func test_handlePlayerFailureFallsBackFromDirectToLiveWhenNoOutputExists() async throws {
    let item = Self.item(outputs: [], sources: [Self.source(codec: .h264, height: 1080)])
    let coordinator = PlaybackCoordinator(
      reporter: FakeReporter(),
      item: item,
      capabilities: Self.caps(codecs: [.h264], maxHeight: 1080)
    )

    _ = try await coordinator.prepare()
    let fallback = try await coordinator.handlePlayerFailure(TestError.failure)

    XCTAssertEqual(
      fallback.source,
      .hlsLive(
        masterURL: Self.liveURL(sourceID: Self.id(100), profile: "h264-1080p"),
        profile: "h264-1080p")
    )
  }

  func test_handlePlayerFailureThrowsFallbackExhaustedFromLive() async throws {
    let item = Self.item(outputs: [], sources: [Self.source(codec: .hevc, height: 2160)])
    let coordinator = PlaybackCoordinator(
      reporter: FakeReporter(),
      item: item,
      capabilities: Self.caps(codecs: [.h264], maxHeight: 1080)
    )

    _ = try await coordinator.prepare()

    do {
      _ = try await coordinator.handlePlayerFailure(TestError.failure)
      XCTFail("Expected fallbackExhausted")
    } catch KinoError.playback(.fallbackExhausted) {
    } catch {
      XCTFail("Expected fallbackExhausted, got \(error)")
    }
  }

  func test_handlePlayerFailureThrowsFallbackExhaustedBeforePrepare() async {
    let coordinator = PlaybackCoordinator(
      reporter: FakeReporter(),
      item: Self.item(outputs: []),
      capabilities: Self.caps(codecs: [.h264], maxHeight: 1080)
    )

    do {
      _ = try await coordinator.handlePlayerFailure(TestError.failure)
      XCTFail("Expected fallbackExhausted")
    } catch KinoError.playback(.fallbackExhausted) {
    } catch {
      XCTFail("Expected fallbackExhausted, got \(error)")
    }
  }

  private enum TestError: Error {
    case failure
  }

  private actor FakeReporter: PlaybackReporting {
    func reportProgress(itemID: UUID, seconds: Double) async throws {}

    func markWatched(itemID: UUID) async throws {}
  }

  private static func caps(codecs: Set<Codec>, maxHeight: Int) -> ClientCapabilities {
    ClientCapabilities(
      codecs: codecs,
      hdr: [],
      maxHeight: maxHeight,
      surroundAudio: false,
      atmos: false
    )
  }

  private static func item(
    outputs: [TranscodeOutput],
    sources: [SourceFile] = [source(codec: .h264, height: 1080)]
  ) -> MediaItem {
    MediaItem(
      id: id(900),
      title: "Coordinator Test",
      runtimeSeconds: 7_200,
      sourceFiles: sources,
      transcodeOutputs: outputs,
      subtitleTracks: [],
      resumeAt: nil
    )
  }

  private static func source(
    id sourceID: Int = 100,
    container: String = "mp4",
    codec: Codec,
    hdr: HDRFormat? = nil,
    height: Int
  ) -> SourceFile {
    SourceFile(
      id: id(sourceID),
      container: container,
      codec: codec,
      hdr: hdr,
      height: height,
      url: sourceURL(sourceID)
    )
  }

  private static func output(
    id outputID: Int,
    codec: Codec,
    height: Int
  ) -> TranscodeOutput {
    TranscodeOutput(
      id: id(outputID),
      container: "hls",
      codec: codec,
      hdr: nil,
      height: height,
      vmafTarget: 92,
      createdAt: Date(timeIntervalSince1970: 100),
      masterURL: outputURL(outputID)
    )
  }

  private static func id(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
  }

  private static func sourceURL(_ value: Int) -> URL {
    URL(string: "https://kino.test/source/\(value).mp4")!
  }

  private static func outputURL(_ value: Int) -> URL {
    URL(string: "https://kino.test/transcodes/\(value)/master.m3u8")!
  }

  private static func liveURL(sourceID: UUID, profile: String) -> URL {
    URL(string: "/api/v1/stream/live/\(sourceID.uuidString)/\(profile)/master.m3u8")!
  }
}
