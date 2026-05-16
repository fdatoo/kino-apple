/// Apple client platform identifier sent during pairing.
public enum ClientPlatform: String, Sendable, Codable, Hashable {
  /// iPhone or iPad client.
  case iOS

  /// Apple TV client.
  case tvOS

  /// Mac client.
  case macOS
}
