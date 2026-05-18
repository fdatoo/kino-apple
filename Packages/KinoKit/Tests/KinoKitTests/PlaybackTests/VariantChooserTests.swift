import Foundation
import XCTest

@testable import KinoKit

final class VariantChooserTests: XCTestCase {
  func test_chooseCoversEveryAlgorithmBranch() {
    for testCase in Self.cases {
      let plan = VariantChooser.choose(item: testCase.item, capabilities: testCase.capabilities)

      XCTAssertEqual(plan.source, testCase.expectedSource, testCase.name)
      XCTAssertEqual(plan.subtitleTracks, testCase.item.subtitleTracks, testCase.name)
      XCTAssertEqual(plan.resumeAt, testCase.item.resumeAt, testCase.name)
    }
  }

  private static let sourceID = id(100)

  private struct ChoiceCase {
    let name: String
    let capabilities: ClientCapabilities
    let item: MediaItem
    let expectedSource: PlaybackPlan.Source
  }

  private static var cases: [ChoiceCase] {
    [
      ChoiceCase(
        name: "Q1 selects single matching output",
        capabilities: caps(codecs: [.h264], maxHeight: 1080),
        item: item(
          outputs: [output(id: 1, codec: .h264, height: 1080)],
          sources: [source(codec: .hevc, height: 2160)]
        ),
        expectedSource: .hlsTranscodeOutput(masterURL: outputURL(1), outputID: id(1))
      ),
      ChoiceCase(
        name: "Q1 ranks by VMAF descending",
        capabilities: caps(codecs: [.h264], maxHeight: 1080),
        item: item(outputs: [
          output(id: 2, codec: .h264, height: 1080, vmafTarget: 90),
          output(id: 3, codec: .h264, height: 1080, vmafTarget: 94),
        ]),
        expectedSource: .hlsTranscodeOutput(masterURL: outputURL(3), outputID: id(3))
      ),
      ChoiceCase(
        name: "Q1 ranks by height after VMAF tie",
        capabilities: caps(codecs: [.h264], maxHeight: 2160),
        item: item(outputs: [
          output(id: 4, codec: .h264, height: 720, vmafTarget: 92),
          output(id: 5, codec: .h264, height: 1080, vmafTarget: 92),
        ]),
        expectedSource: .hlsTranscodeOutput(masterURL: outputURL(5), outputID: id(5))
      ),
      ChoiceCase(
        name: "Q1 ranks by creation time after quality tie",
        capabilities: caps(codecs: [.h264], maxHeight: 2160),
        item: item(outputs: [
          output(id: 6, codec: .h264, height: 1080, vmafTarget: nil, createdAt: 100),
          output(id: 7, codec: .h264, height: 1080, vmafTarget: nil, createdAt: 200),
        ]),
        expectedSource: .hlsTranscodeOutput(masterURL: outputURL(7), outputID: id(7))
      ),
      ChoiceCase(
        name: "Q1 rejects non-HLS output then Q2 direct plays",
        capabilities: caps(codecs: [.h264], maxHeight: 1080),
        item: item(
          outputs: [output(id: 8, container: "mp4", codec: .h264, height: 1080)],
          sources: [source(codec: .h264, height: 1080)]
        ),
        expectedSource: .directByteRange(sourceURL(100))
      ),
      ChoiceCase(
        name: "Q1 rejects unsupported output codec then Q2 direct plays",
        capabilities: caps(codecs: [.h264], maxHeight: 1080),
        item: item(
          outputs: [output(id: 9, codec: .hevc, height: 1080)],
          sources: [source(codec: .h264, height: 1080)]
        ),
        expectedSource: .directByteRange(sourceURL(100))
      ),
      ChoiceCase(
        name: "Q1 rejects unsupported output HDR then Q2 direct plays",
        capabilities: caps(codecs: [.h264], hdr: [], maxHeight: 1080),
        item: item(
          outputs: [output(id: 10, codec: .h264, hdr: .hdr10, height: 1080)],
          sources: [source(codec: .h264, height: 1080)]
        ),
        expectedSource: .directByteRange(sourceURL(100))
      ),
      ChoiceCase(
        name: "Q1 rejects output above max height then Q2 direct plays",
        capabilities: caps(codecs: [.h264], maxHeight: 720),
        item: item(
          outputs: [output(id: 11, codec: .h264, height: 1080)],
          sources: [source(codec: .h264, height: 720)]
        ),
        expectedSource: .directByteRange(sourceURL(100))
      ),
      ChoiceCase(
        name: "Q2 direct plays supported HDR source",
        capabilities: caps(codecs: [.hevc], hdr: [.hdr10], maxHeight: 2160),
        item: item(outputs: [], sources: [source(codec: .hevc, hdr: .hdr10, height: 2160)]),
        expectedSource: .directByteRange(sourceURL(100))
      ),
      ChoiceCase(
        name: "Q3 live when source container is not direct playable",
        capabilities: caps(codecs: [.h264], maxHeight: 2160),
        item: item(outputs: [], sources: [source(container: "mkv", codec: .h264, height: 1080)]),
        expectedSource: .hlsLive(
          masterURL: liveURL(sourceID: sourceID, profile: "h264-1080p"), profile: "h264-1080p")
      ),
      ChoiceCase(
        name: "Q3 live h264 480p when source codec is unsupported",
        capabilities: caps(codecs: [.h264], maxHeight: 480),
        item: item(outputs: [], sources: [source(codec: .hevc, height: 480)]),
        expectedSource: .hlsLive(
          masterURL: liveURL(sourceID: sourceID, profile: "h264-480p"), profile: "h264-480p")
      ),
      ChoiceCase(
        name: "Q3 live h264 720p when source HDR is unsupported",
        capabilities: caps(codecs: [.h264], hdr: [], maxHeight: 720),
        item: item(outputs: [], sources: [source(codec: .h264, hdr: .hdr10, height: 720)]),
        expectedSource: .hlsLive(
          masterURL: liveURL(sourceID: sourceID, profile: "h264-720p"), profile: "h264-720p")
      ),
      ChoiceCase(
        name: "Q3 live h264 1080p when source exceeds max height",
        capabilities: caps(codecs: [.h264], maxHeight: 1080),
        item: item(outputs: [], sources: [source(codec: .h264, height: 2160)]),
        expectedSource: .hlsLive(
          masterURL: liveURL(sourceID: sourceID, profile: "h264-1080p"), profile: "h264-1080p")
      ),
      ChoiceCase(
        name: "Q3 live hevc 2160p when no source exists",
        capabilities: caps(codecs: [.h264, .hevc], maxHeight: 2160),
        item: item(outputs: [], sources: []),
        expectedSource: .hlsLive(
          masterURL: liveURL(sourceID: nil, profile: "hevc-2160p"), profile: "hevc-2160p")
      ),
      ChoiceCase(
        name: "Q3 live h264 1080p when 2160p client lacks HEVC",
        capabilities: caps(codecs: [.h264], maxHeight: 2160),
        item: item(outputs: [], sources: [source(codec: .av1, height: 2160)]),
        expectedSource: .hlsLive(
          masterURL: liveURL(sourceID: sourceID, profile: "h264-1080p"), profile: "h264-1080p")
      ),
    ]
  }

  private static func caps(
    codecs: Set<Codec>,
    hdr: Set<HDRFormat> = [],
    maxHeight: Int,
    surroundAudio: Bool = false,
    atmos: Bool = false
  ) -> ClientCapabilities {
    ClientCapabilities(
      codecs: codecs,
      hdr: hdr,
      maxHeight: maxHeight,
      surroundAudio: surroundAudio,
      atmos: atmos
    )
  }

  private static func item(
    outputs: [TranscodeOutput],
    sources: [SourceFile] = [source(codec: .h264, height: 1080)]
  ) -> MediaItem {
    MediaItem(
      id: id(900),
      title: "Variant Test",
      runtimeSeconds: 7_200,
      sourceFiles: sources,
      transcodeOutputs: outputs,
      subtitleTracks: [
        SubtitleTrack(
          id: id(901),
          language: "en",
          isForced: false,
          url: URL(string: "https://kino.test/subtitles/en.vtt")!
        )
      ],
      resumeAt: 123
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
    container: String = "hls",
    codec: Codec,
    hdr: HDRFormat? = nil,
    height: Int,
    vmafTarget: Double? = 92,
    createdAt: TimeInterval = 100
  ) -> TranscodeOutput {
    TranscodeOutput(
      id: id(outputID),
      container: container,
      codec: codec,
      hdr: hdr,
      height: height,
      vmafTarget: vmafTarget,
      createdAt: Date(timeIntervalSince1970: createdAt),
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

  private static func liveURL(sourceID: UUID?, profile: String) -> URL {
    // VariantChooser routes the live-fallback case through the unified
    // `/api/v1/stream/items/{itemID}/master.m3u8` endpoint. sourceID and profile
    // are ignored for URL construction; profile is still asserted separately on
    // the `.hlsLive` case associated value.
    URL(string: "/api/v1/stream/items/\(id(900).uuidString)/master.m3u8")!
  }
}
