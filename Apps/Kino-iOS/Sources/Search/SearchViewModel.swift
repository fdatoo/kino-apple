import Foundation
import KinoKit
import Observation
import os

/// Drives the Search tab: debounced parallel library + discover queries, recent-query history, and request submission.
@Observable
@MainActor
final class SearchViewModel {
  private let logger = Logger(subsystem: "kino.ios", category: "search")
  private let recentsKey = "kino.search.recents"
  private let maxRecents = 8
  private let debounce: Duration = .milliseconds(300)

  var query: String = "" {
    didSet { scheduleSearch() }
  }
  var libraryResults: [MediaItem] = []
  var discoverResults: [DiscoverCandidate] = []
  var isSearching = false
  var error: KinoError?

  private(set) var recents: [String] = []
  private var searchTask: Task<Void, Never>?
  private weak var clientRef: KinoClient?

  init() {
    self.recents = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
  }

  /// Injects the KinoClient; call from the view's `.task` block since environment values cannot be captured in init.
  func bind(_ client: KinoClient) {
    self.clientRef = client
  }

  /// Records a non-empty query in the recents list. Call when the user formally submits.
  func submit() {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    recents.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
    recents.insert(trimmed, at: 0)
    if recents.count > maxRecents { recents.removeLast(recents.count - maxRecents) }
    UserDefaults.standard.set(recents, forKey: recentsKey)
  }

  /// Requests a TMDB candidate via the server; surfaces server errors into `error`.
  func submitRequest(for candidate: DiscoverCandidate, client: KinoClient) async {
    do {
      _ = try await client.requests.create(kind: candidate.kind, tmdbID: Int(candidate.tmdbId))
      discoverResults.removeAll { $0.tmdbId == candidate.tmdbId }
    } catch let kinoError as KinoError {
      self.error = kinoError
      logger.error("requests.create failed: \(String(describing: kinoError))")
    } catch {
      self.error = .decoding(error)
      logger.error("requests.create decoding failed: \(String(describing: error))")
    }
  }

  private func scheduleSearch() {
    searchTask?.cancel()
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
      libraryResults = []
      discoverResults = []
      isSearching = false
      return
    }
    searchTask = Task { [weak self] in
      guard let self else { return }
      try? await Task.sleep(for: self.debounce)
      if Task.isCancelled { return }
      guard let client = self.clientRef else { return }
      await self.performSearch(trimmed, client: client)
    }
  }

  private func performSearch(_ q: String, client: KinoClient) async {
    isSearching = true
    defer { isSearching = false }
    async let library = client.library.list(limit: 30, q: q)
    async let movies = client.discover.search(q: q, kind: .movie)
    async let series = client.discover.search(q: q, kind: .series)
    do {
      let (lib, m, s) = try await (library, movies, series)
      libraryResults = lib
      var merged = m.candidates + s.candidates
      merged.sort { $0.popularity > $1.popularity }
      discoverResults = merged
      self.error = nil
    } catch let kinoError as KinoError {
      self.error = kinoError
      logger.error("search failed: \(String(describing: kinoError))")
    } catch {
      self.error = .decoding(error)
      logger.error("search decoding failed: \(String(describing: error))")
    }
  }
}
