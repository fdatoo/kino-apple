import Foundation
import KinoKitCore

/// Chooses the best playback variant for one media item and client capability set.
public enum VariantChooser {
  /// Builds a playback plan using cached compatible output, direct play, then live transcode.
  public static func choose(item: MediaItem, capabilities: ClientCapabilities) -> PlaybackPlan {
    let compatibleOutputs = item.transcodeOutputs.filter { capabilities.canPlay($0) }
    if let bestOutput = compatibleOutputs.sorted(by: rank).first {
      return PlaybackPlan(
        source: .hlsTranscodeOutput(masterURL: bestOutput.masterURL, outputID: bestOutput.id),
        subtitleTracks: item.subtitleTracks,
        resumeAt: item.resumeAt
      )
    }

    if let sourceFile = item.sourceFiles.first, capabilities.canDirectPlay(sourceFile) {
      return PlaybackPlan(
        source: .directByteRange(sourceFile.url),
        subtitleTracks: item.subtitleTracks,
        resumeAt: item.resumeAt
      )
    }

    let profile = liveProfile(for: capabilities)
    return PlaybackPlan(
      source: .hlsLive(masterURL: liveMasterURL(item: item, profile: profile), profile: profile),
      subtitleTracks: item.subtitleTracks,
      resumeAt: item.resumeAt
    )
  }

  static func liveProfile(for capabilities: ClientCapabilities) -> String {
    switch capabilities.maxHeight {
    case ..<720:
      return "h264-480p"
    case 720..<1080:
      return "h264-720p"
    case 1080..<2160:
      return "h264-1080p"
    default:
      return capabilities.codecs.contains(.hevc) ? "hevc-2160p" : "h264-1080p"
    }
  }

  static func liveMasterURL(item: MediaItem, profile: String) -> URL {
    let sourceID = item.sourceFiles.first?.id.uuidString ?? "unknown"
    return URL(string: "/api/v1/stream/live/\(sourceID)/\(profile)/master.m3u8")!
  }

  private static func rank(_ lhs: TranscodeOutput, _ rhs: TranscodeOutput) -> Bool {
    let left = (lhs.vmafTarget ?? 0, lhs.height, lhs.createdAt)
    let right = (rhs.vmafTarget ?? 0, rhs.height, rhs.createdAt)
    return left > right
  }
}

extension ClientCapabilities {
  func canPlay(_ output: TranscodeOutput) -> Bool {
    output.container.lowercased() == "hls"
      && codecs.contains(output.codec)
      && (output.hdr.map { hdr.contains($0) } ?? true)
      && output.height <= maxHeight
  }

  func canDirectPlay(_ source: SourceFile) -> Bool {
    let directContainers = Set(["mp4", "m4v", "mov"])
    return directContainers.contains(source.container.lowercased())
      && codecs.contains(source.codec)
      && (source.hdr.map { hdr.contains($0) } ?? true)
      && source.height <= maxHeight
  }
}
