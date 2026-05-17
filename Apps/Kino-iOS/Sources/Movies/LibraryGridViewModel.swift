import Foundation
import KinoKit
import Observation
import os

/// Paginates the catalog filtered by media kind.
@Observable
@MainActor
final class LibraryGridViewModel {
  /// The kind of media to display in the grid.
  enum Kind: Sendable {
    case movie
    case series

    /// The raw query value sent to the server.
    fileprivate var queryValue: String {
      switch self {
      case .movie: "movie"
      case .series: "tv_episode"
      }
    }
  }

  private let logger = Logger(subsystem: "kino.ios", category: "library")
  private let pageSize = 30

  let kind: Kind
  var items: [MediaItem] = []
  var isLoading = false
  var error: KinoError?
  private var offset = 0
  private var hasMore = true

  init(kind: Kind) { self.kind = kind }

  /// Loads the first page of items if none are loaded yet.
  func loadInitial(_ client: KinoClient) async {
    guard items.isEmpty else { return }
    offset = 0
    hasMore = true
    await loadMore(client)
  }

  /// Appends the next page of items.
  func loadMore(_ client: KinoClient) async {
    guard !isLoading, hasMore else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      let batch = try await client.library.list(
        kind: kind.queryValue,
        limit: pageSize,
        offset: offset,
        q: nil
      )
      items.append(contentsOf: batch)
      offset += batch.count
      if batch.count < pageSize { hasMore = false }
    } catch let error as KinoError {
      self.error = error
      logger.error("library list failed: \(String(describing: error))")
    } catch {
      self.error = .decoding(error)
      logger.error("library list decoding failed: \(String(describing: error))")
    }
  }
}
