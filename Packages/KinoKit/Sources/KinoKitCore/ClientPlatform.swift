/// Apple client platform identifier sent during pairing.
///
/// Raw values are the on-wire lowercase form the kino server expects. Surfaced
/// by manual probe acceptance: the default Swift-case raw values (`iOS`,
/// `tvOS`, `macOS`) made `POST /api/v1/pairings` fail with HTTP 400 because
/// the server's enum is `ios | tvos | macos`.
public enum ClientPlatform: String, Sendable, Codable, Hashable {
  /// iPhone or iPad client.
  case iOS = "ios"

  /// Apple TV client.
  case tvOS = "tvos"

  /// Mac client.
  case macOS = "macos"
}
