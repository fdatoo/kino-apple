import Foundation
import KinoKit
import Observation
import os

/// Loads a single library item for the detail view.
@Observable
@MainActor
final class ItemDetailViewModel {
  private let logger = Logger(subsystem: "kino.ios", category: "library")

  var item: MediaItem?
  var error: KinoError?
  var isLoading = false

  /// Fetches the media item with the given `id` from the library.
  func load(id: UUID, client: KinoClient) async {
    isLoading = true
    defer { isLoading = false }
    do {
      item = try await client.library.get(id: id)
    } catch let error as KinoError {
      self.error = error
      logger.error("library.get failed: \(String(describing: error))")
    } catch {
      self.error = .decoding(error)
      logger.error("library.get decoding failed: \(String(describing: error))")
    }
  }
}
