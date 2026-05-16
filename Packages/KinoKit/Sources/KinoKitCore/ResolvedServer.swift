import Foundation

/// Server endpoint resolved from a discovered local network advertisement.
public struct ResolvedServer: Sendable, Hashable, Codable {
  /// Stable server instance identifier.
  public let instanceID: UUID

  /// Host name or IP address clients should connect to.
  public let host: String

  /// TCP port for the Kino API.
  public let port: Int

  /// API version exposed by the server, such as `v1`.
  public let apiVersion: String

  /// Server semantic version advertised during discovery.
  public let serverVersion: String

  /// Creates a resolved server endpoint.
  public init(
    instanceID: UUID,
    host: String,
    port: Int,
    apiVersion: String,
    serverVersion: String
  ) {
    self.instanceID = instanceID
    self.host = host
    self.port = port
    self.apiVersion = apiVersion
    self.serverVersion = serverVersion
  }
}
