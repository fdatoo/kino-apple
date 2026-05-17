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
  /// Default iPhone/iPad capabilities for M3-era kino clients.
  ///
  /// Codecs: H.264 + HEVC + AV1. **AV1 hardware decode requires A14+ (iPhone 12 or newer)**;
  /// on older iOS 17–capable devices (iPhone XR/XS/11/SE-2) the server may select AV1 and
  /// the device will fall back to software decode (high CPU, dropped frames). A runtime
  /// AV1 probe via `VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)` is the right
  /// long-term fix; tracked as a follow-up.
  ///
  /// HDR: HDR10 + Dolby Vision + HLG.
  /// Resolution: up to 2160p. Surround + Atmos enabled.
  public static let iOS17Default = ClientCapabilities(
    codecs: [.h264, .hevc, .av1],
    hdr: [.hdr10, .dolbyVision, .hlg],
    maxHeight: 2160,
    surroundAudio: true,
    atmos: true
  )
}
