import Foundation
import KinoKit
import Observation
import os

/// Application-wide authentication phase.
enum AppPhase: Sendable {
  case loading
  case unauthenticated
  case authenticated(KinoClient)
  case error(KinoError)
}

/// Observable root state holding the current auth phase and optional global error banner.
@Observable
@MainActor
final class AppState {
  private let store: any SessionStore
  private let logger = Logger(subsystem: "kino.ios", category: "appstate")

  var phase: AppPhase = .loading
  var errorBanner: KinoError?

  init(store: any SessionStore = KeychainSessionStore()) {
    self.store = store
    Task { await self.loadSession() }
  }

  func loadSession() async {
    do {
      let sessions = try await store.loadAll()
      guard let session = sessions.last else {
        phase = .unauthenticated
        return
      }
      phase = .authenticated(KinoClient(session: session))
    } catch let error as KinoError {
      phase = .error(error)
    } catch {
      phase = .error(.decoding(error))
    }
  }

  func signedIn(_ session: AuthorizedSession) async {
    do { try await store.save(session) } catch {
      logger.error("Failed to persist session: \(String(describing: error))")
    }
    phase = .authenticated(KinoClient(session: session))
  }

  func signOut() async {
    guard case .authenticated(let client) = phase else { return }
    try? await store.remove(serverInstanceID: client.session.serverInstanceID)
    phase = .unauthenticated
  }
}
