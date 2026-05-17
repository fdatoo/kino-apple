import Foundation
import KinoKit
import Observation
import os

/// Exposes session-derived configuration values for the Settings screen.
@Observable
@MainActor
final class SettingsViewModel {
  private let logger = Logger(subsystem: "kino.ios", category: "settings")

  private var client: KinoClient?

  /// The server's hostname, or "—" if unavailable.
  var hostname: String {
    client?.session.baseURL.host ?? "—"
  }

  /// The API version in use; currently always "v1".
  var apiVersion: String { "v1" }

  /// The server instance UUID string, or "—" if unavailable.
  var instanceID: String {
    client?.session.serverInstanceID.uuidString ?? "—"
  }

  /// The user ID for the current session, or "—" if unavailable.
  var userID: String {
    client?.session.userID.uuidString ?? "—"
  }

  /// The device name registered with the server, or "—" if unavailable.
  var deviceName: String {
    client?.session.deviceName ?? "—"
  }

  /// Whether the current session has administrative privileges.
  var isAdmin: Bool {
    client?.session.isAdmin ?? false
  }

  /// Binds the settings view model to the active client; call from the view's `.task` block.
  func bind(_ client: KinoClient) {
    self.client = client
    logger.debug("settings bound to \(client.session.baseURL.absoluteString)")
  }
}
