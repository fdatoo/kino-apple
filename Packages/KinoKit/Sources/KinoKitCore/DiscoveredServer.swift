import Foundation

/// Server advertised by local network discovery before endpoint resolution.
public struct DiscoveredServer: Sendable, Hashable {
  /// Stable server instance identifier advertised in the TXT record.
  public let instanceID: UUID

  /// Bonjour instance name.
  public let name: String

  /// Raw TXT record values, including version and API metadata.
  public let txt: [String: String]

  /// Creates a discovered server value from Bonjour metadata.
  public init(instanceID: UUID, name: String, txt: [String: String]) {
    self.instanceID = instanceID
    self.name = name
    self.txt = txt
  }
}
