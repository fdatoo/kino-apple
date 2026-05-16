import Foundation

/// Minimal playback reporting surface used by `PlaybackCoordinator`.
public protocol PlaybackReporting: Sendable {
  /// Reports playback progress for an item at the provided offset.
  func reportProgress(itemID: UUID, seconds: Double) async throws

  /// Marks an item watched for the current user.
  func markWatched(itemID: UUID) async throws
}
