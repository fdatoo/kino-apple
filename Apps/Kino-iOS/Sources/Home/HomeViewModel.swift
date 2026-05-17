import Foundation
import KinoKit
import Observation
import os

/// Drives the Home tab: parallel loads of continue-watching, recently-added, and recent requests.
@Observable
@MainActor
final class HomeViewModel {
  private let logger = Logger(subsystem: "kino.ios", category: "home")
  private let recentRequestsLimit = 5

  var continueWatching: [InProgressItem] = []
  var recentlyAdded: [MediaItem] = []
  var recentRequests: [RequestSummary] = []
  var isLoading = false
  var error: KinoError?

  /// Loads all Home tab data in parallel; replaces any previously loaded data.
  func load(_ client: KinoClient) async {
    isLoading = true
    error = nil
    defer { isLoading = false }

    async let cw = client.playback.listInProgress(limit: 10)
    async let ra = client.library.list(sort: "recently_added", limit: 20)
    async let rr = client.requests.list()

    do {
      let (cwResult, raResult, rrResult) = try await (cw, ra, rr)
      continueWatching = cwResult
      recentlyAdded = raResult
      recentRequests = Array(rrResult.prefix(recentRequestsLimit))
      logger.info(
        "home loaded: \(cwResult.count) in-progress, \(raResult.count) recently-added, \(rrResult.count) requests"
      )
    } catch let err as KinoError {
      error = err
      logger.error("home load failed: \(String(describing: err))")
    } catch {
      self.error = .decoding(error)
      logger.error("home load decoding failed: \(String(describing: error))")
    }
  }
}
