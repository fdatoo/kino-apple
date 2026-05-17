/// Playback capabilities reported by a client device.
public struct ClientCapabilities: Sendable, Hashable, Codable {
  /// Video codecs the client can decode.
  public let codecs: Set<Codec>

  /// HDR formats the client can render.
  public let hdr: Set<HDRFormat>

  /// Maximum video height the client should select.
  public let maxHeight: Int

  /// Whether the client can play surround audio.
  public let surroundAudio: Bool

  /// Whether the client can play Dolby Atmos audio.
  public let atmos: Bool

  /// Creates a client capabilities value.
  public init(
    codecs: Set<Codec>,
    hdr: Set<HDRFormat>,
    maxHeight: Int,
    surroundAudio: Bool,
    atmos: Bool
  ) {
    self.codecs = codecs
    self.hdr = hdr
    self.maxHeight = maxHeight
    self.surroundAudio = surroundAudio
    self.atmos = atmos
  }
}

extension ClientCapabilities {
  /// Default iOS 17+ iPhone/iPad capabilities: H.264 + HEVC + AV1, HDR10 + Dolby Vision, 2160p, surround + Atmos.
  public static let iOS17Default = ClientCapabilities(
    codecs: [.h264, .hevc, .av1],
    hdr: [.hdr10, .dolbyVision],
    maxHeight: 2160,
    surroundAudio: true,
    atmos: true
  )
}
