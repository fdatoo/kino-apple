import Foundation
import KinoKit
import Observation
import os

/// Drives the Requests screen: loads and refreshes the list of media requests for the current session.
@Observable
@MainActor
final class RequestsViewModel {
  private let logger = Logger(subsystem: "kino.ios", category: "requests")

  var requests: [RequestSummary] = []
  var isLoading = false
  var error: KinoError?

  /// Loads all requests; replaces any previously loaded data.
  func load(_ client: KinoClient) async {
    isLoading = true
    error = nil
    defer { isLoading = false }
    do {
      requests = try await client.requests.list()
      logger.info("requests loaded: \(self.requests.count)")
    } catch let err as KinoError {
      error = err
      logger.error("requests load failed: \(String(describing: err))")
    } catch {
      self.error = .decoding(error)
      logger.error("requests load decoding failed: \(String(describing: error))")
    }
  }

  /// Refreshes the requests list; semantically identical to `load(_:)` and suitable for `.refreshable`.
  func refresh(_ client: KinoClient) async {
    await load(client)
  }
}
