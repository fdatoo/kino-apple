import Foundation
import KinoKitCore

/// Playback decision produced by KinoKit for a media item on one client.
public struct PlaybackPlan: Sendable, Hashable {
  /// Stream source selected for playback.
  public enum Source: Sendable, Hashable {
    /// Direct byte-range playback of an existing source file.
    case directByteRange(URL)

    /// HLS playback of a cached transcode output.
    case hlsTranscodeOutput(masterURL: URL, outputID: UUID)

    /// HLS playback through an on-demand live transcode profile.
    case hlsLive(masterURL: URL, profile: String)
  }

  /// Stream source selected for playback.
  public let source: Source

  /// Subtitle tracks available alongside the selected stream.
  public let subtitleTracks: [SubtitleTrack]

  /// Resume offset in seconds when known.
  public let resumeAt: TimeInterval?

  /// Creates a playback plan value.
  public init(source: Source, subtitleTracks: [SubtitleTrack], resumeAt: TimeInterval?) {
    self.source = source
    self.subtitleTracks = subtitleTracks
    self.resumeAt = resumeAt
  }
}
