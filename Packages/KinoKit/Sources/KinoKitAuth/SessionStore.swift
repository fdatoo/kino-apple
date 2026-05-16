import Foundation
import KinoKitCore

/// Persists authorized sessions for all known Kino server instances.
public protocol SessionStore: Sendable {
  /// Loads every stored session sorted by creation time.
  func loadAll() async throws -> [AuthorizedSession]

  /// Saves or replaces the session for its server instance.
  func save(_ session: AuthorizedSession) async throws

  /// Removes the session for a server instance, if one exists.
  func remove(serverInstanceID: UUID) async throws
}
