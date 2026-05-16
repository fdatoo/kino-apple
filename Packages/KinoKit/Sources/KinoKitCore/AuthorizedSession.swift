import Foundation

/// Authorized device session persisted by clients for future requests.
public struct AuthorizedSession: Sendable, Hashable, Codable {
  /// Stable server instance this session belongs to.
  public let serverInstanceID: UUID

  /// Base URL used for authenticated API requests.
  public let baseURL: URL

  /// Stable identifier for the issued device token.
  public let tokenID: UUID

  /// Bearer token secret; callers must not log this value.
  public let token: String

  /// User identifier associated with the authorized session.
  public let userID: UUID

  /// Client device name shown to the server operator.
  public let deviceName: String

  /// Time the session was created.
  public let createdAt: Date

  /// Whether the session can use administrative API surfaces.
  public let isAdmin: Bool

  /// Creates an authorized session value.
  public init(
    serverInstanceID: UUID,
    baseURL: URL,
    tokenID: UUID,
    token: String,
    userID: UUID,
    deviceName: String,
    createdAt: Date,
    isAdmin: Bool = false
  ) {
    self.serverInstanceID = serverInstanceID
    self.baseURL = baseURL
    self.tokenID = tokenID
    self.token = token
    self.userID = userID
    self.deviceName = deviceName
    self.createdAt = createdAt
    self.isAdmin = isAdmin
  }

  /// Decodes an authorized session, defaulting missing admin scope to false for older stored blobs.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    serverInstanceID = try container.decode(UUID.self, forKey: .serverInstanceID)
    baseURL = try container.decode(URL.self, forKey: .baseURL)
    tokenID = try container.decode(UUID.self, forKey: .tokenID)
    token = try container.decode(String.self, forKey: .token)
    userID = try container.decode(UUID.self, forKey: .userID)
    deviceName = try container.decode(String.self, forKey: .deviceName)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    isAdmin = try container.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false
  }
}
