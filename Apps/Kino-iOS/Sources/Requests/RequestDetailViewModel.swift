import Foundation
import KinoKit
import Observation
import os

/// Drives the Request Detail screen: loads and updates a single request's full detail projection.
@Observable
@MainActor
final class RequestDetailViewModel {
  private let logger = Logger(subsystem: "kino.ios", category: "requests")

  var detail: RequestDetail?
  var isLoading = false
  var error: KinoError?

  /// Loads the full detail for the given request ID.
  func load(id: String, client: KinoClient) async {
    guard let uuid = UUID(uuidString: id) else {
      logger.error("invalid request id: \(id)")
      return
    }
    isLoading = true
    error = nil
    defer { isLoading = false }
    do {
      detail = try await client.requests.get(id: uuid)
      logger.info("request detail loaded: \(id)")
    } catch let err as KinoError {
      error = err
      logger.error("request detail load failed: \(String(describing: err))")
    } catch {
      self.error = .decoding(error)
      logger.error("request detail load decoding failed: \(String(describing: error))")
    }
  }

  /// Cancels the request and refreshes the detail with the updated state.
  func cancel(id: String, client: KinoClient) async {
    guard let uuid = UUID(uuidString: id) else {
      logger.error("invalid request id for cancel: \(id)")
      return
    }
    isLoading = true
    error = nil
    defer { isLoading = false }
    do {
      detail = try await client.requests.cancel(id: uuid)
      logger.info("request cancelled: \(id)")
    } catch let err as KinoError {
      error = err
      logger.error("request cancel failed: \(String(describing: err))")
    } catch {
      self.error = .decoding(error)
      logger.error("request cancel decoding failed: \(String(describing: error))")
    }
  }
}
