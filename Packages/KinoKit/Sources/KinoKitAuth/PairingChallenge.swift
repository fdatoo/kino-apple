import Foundation

/// Pairing code issued by a Kino server while waiting for admin approval.
public struct PairingChallenge: Sendable, Hashable, Codable {
  /// Persisted pairing identifier on the server.
  public let pairingID: UUID

  /// Short pairing code shown to the user for admin approval.
  public let code: String

  /// Wall-clock expiry for the pairing code.
  public let expiresAt: Date

  /// Device name the client requested during code issuance. Carried so the
  /// resulting `AuthorizedSession` can be populated without re-prompting.
  public let deviceName: String

  /// Creates a pairing challenge value.
  public init(pairingID: UUID, code: String, expiresAt: Date, deviceName: String) {
    self.pairingID = pairingID
    self.code = code
    self.expiresAt = expiresAt
    self.deviceName = deviceName
  }
}
