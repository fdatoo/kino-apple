import Foundation

/// Video codec label used by client capability and media variant selection.
public enum Codec: String, Sendable, Codable, Hashable, CaseIterable {
  /// H.264 / AVC video.
  case h264

  /// H.265 / HEVC video.
  case hevc

  /// AV1 video.
  case av1
}

/// HDR format label used by client capability and media variant selection.
public enum HDRFormat: String, Sendable, Codable, Hashable, CaseIterable {
  /// HDR10 video.
  case hdr10

  /// Dolby Vision video.
  case dolbyVision

  /// Hybrid log-gamma video.
  case hlg
}

/// Subtitle track exposed for playback.
public struct SubtitleTrack: Sendable, Hashable, Codable {
  /// Stable subtitle track identifier.
  public let id: UUID

  /// Normalized language tag.
  public let language: String

  /// Whether the subtitle is marked forced.
  public let isForced: Bool

  /// URL for the subtitle sidecar or stream.
  public let url: URL

  /// Creates a subtitle track value.
  public init(id: UUID, language: String, isForced: Bool, url: URL) {
    self.id = id
    self.language = language
    self.isForced = isForced
    self.url = url
  }
}

/// Source media file variant that can be streamed directly.
public struct SourceFile: Sendable, Hashable, Codable {
  /// Stable source file identifier.
  public let id: UUID

  /// Container format label.
  public let container: String

  /// Video codec label.
  public let codec: Codec

  /// HDR format when the source is HDR.
  public let hdr: HDRFormat?

  /// Video height in pixels.
  public let height: Int

  /// URL for direct source streaming.
  public let url: URL

  /// Creates a source file value.
  public init(id: UUID, container: String, codec: Codec, hdr: HDRFormat?, height: Int, url: URL) {
    self.id = id
    self.container = container
    self.codec = codec
    self.hdr = hdr
    self.height = height
    self.url = url
  }
}

/// Cached transcode output variant that can be streamed as HLS.
public struct TranscodeOutput: Sendable, Hashable, Codable {
  /// Stable transcode output identifier.
  public let id: UUID

  /// Container format label.
  public let container: String

  /// Video codec label.
  public let codec: Codec

  /// HDR format when the output is HDR.
  public let hdr: HDRFormat?

  /// Video height in pixels.
  public let height: Int

  /// Target VMAF quality score used when the output was planned.
  public let vmafTarget: Double?

  /// Time the transcode output was created.
  public let createdAt: Date

  /// HLS master playlist URL for this output.
  public let masterURL: URL

  /// Creates a transcode output value.
  public init(
    id: UUID,
    container: String,
    codec: Codec,
    hdr: HDRFormat?,
    height: Int,
    vmafTarget: Double?,
    createdAt: Date,
    masterURL: URL
  ) {
    self.id = id
    self.container = container
    self.codec = codec
    self.hdr = hdr
    self.height = height
    self.vmafTarget = vmafTarget
    self.createdAt = createdAt
    self.masterURL = masterURL
  }
}

/// Narrow client-facing media item shape consumed by KinoKit playback.
public struct MediaItem: Sendable, Hashable, Codable {
  /// Stable media item identifier.
  public let id: UUID

  /// Display title.
  public let title: String

  /// Runtime in whole seconds when known.
  public let runtimeSeconds: Int?

  /// Direct source file variants.
  public let sourceFiles: [SourceFile]

  /// Cached transcode output variants.
  public let transcodeOutputs: [TranscodeOutput]

  /// Subtitle tracks available for playback.
  public let subtitleTracks: [SubtitleTrack]

  /// Resume offset in seconds when the current user has progress.
  public let resumeAt: TimeInterval?

  /// Creates a media item value.
  public init(
    id: UUID,
    title: String,
    runtimeSeconds: Int?,
    sourceFiles: [SourceFile],
    transcodeOutputs: [TranscodeOutput],
    subtitleTracks: [SubtitleTrack],
    resumeAt: TimeInterval?
  ) {
    self.id = id
    self.title = title
    self.runtimeSeconds = runtimeSeconds
    self.sourceFiles = sourceFiles
    self.transcodeOutputs = transcodeOutputs
    self.subtitleTracks = subtitleTracks
    self.resumeAt = resumeAt
  }
}
