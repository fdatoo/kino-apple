import XCTest

@testable import KinoKit

final class MediaItemCodableTests: XCTestCase {
  func test_roundTrip() throws {
    let item = MediaItem(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
      title: "Test Movie",
      runtimeSeconds: 7_200,
      sourceFiles: [
        SourceFile(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
          container: "mp4",
          codec: .hevc,
          hdr: .hdr10,
          height: 2160,
          url: URL(string: "http://kino.local:7000/api/v1/stream/source/1")!
        )
      ],
      transcodeOutputs: [
        TranscodeOutput(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
          container: "hls",
          codec: .h264,
          hdr: nil,
          height: 1080,
          vmafTarget: 93.5,
          createdAt: Date(timeIntervalSince1970: 1_700_000_100),
          masterURL: URL(string: "http://kino.local:7000/api/v1/stream/transcodes/1/master.m3u8")!
        )
      ],
      subtitleTracks: [
        SubtitleTrack(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
          language: "en",
          isForced: false,
          url: URL(string: "http://kino.local:7000/api/v1/subtitles/1.vtt")!
        )
      ],
      resumeAt: 123.5
    )

    let data = try JSONEncoder().encode(item)
    let decoded = try JSONDecoder().decode(MediaItem.self, from: data)

    XCTAssertEqual(decoded, item)
  }

  func test_mediaEnumsExposeExpectedCases() {
    XCTAssertEqual(Codec.allCases.count, 3)
    XCTAssertEqual(HDRFormat.allCases.count, 3)
  }
}
