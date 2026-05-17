import Foundation
import KinoKit
import Observation
import UIKit
import os

/// Drives the pairing flow: discovery, server selection, code request, and approval polling.
@Observable
@MainActor
final class PairingViewModel {
  /// The current phase of the pairing flow.
  enum Phase: Sendable {
    case discovering([DiscoveredServer])
    case requestingCode(ResolvedServer)
    case awaitingApproval(PairingChallenge, ResolvedServer)
    case failed(PairingError)
  }

  private let logger = Logger(subsystem: "kino.ios", category: "pairing")
  private let discovery = ServerDiscovery()
  private var discoveryTask: Task<Void, Never>?
  private var pollTask: Task<Void, Never>?
  private weak var appState: AppState?

  var phase: Phase = .discovering([])

  /// Bind to the global AppState so a successful pairing can transition app phase.
  func bind(_ state: AppState) { self.appState = state }

  /// Starts background mDNS discovery; idempotent.
  func startDiscovery() {
    discoveryTask?.cancel()
    discoveryTask = Task { [weak self] in
      guard let self else { return }
      let stream = await self.discovery.browse()
      for await server in stream {
        guard case .discovering(var current) = self.phase else { return }
        if !current.contains(where: { $0.instanceID == server.instanceID }) {
          current.append(server)
          self.phase = .discovering(current)
        }
      }
    }
  }

  /// Cancels the discovery browser and any in-flight pairing approval poll.
  func stopDiscovery() {
    discoveryTask?.cancel()
    discoveryTask = nil
    pollTask?.cancel()
    pollTask = nil
  }

  /// Resolves a discovered server then requests a pairing code.
  func select(_ server: DiscoveredServer) async {
    do {
      let resolved = try await discovery.resolve(server)
      await requestCode(for: resolved)
    } catch {
      logger.error("resolve failed: \(String(describing: error))")
      phase = .failed(.malformedResponse)
    }
  }

  /// Validates a user-entered URL and proceeds straight to code request.
  func enterManualURL(_ raw: String) async {
    guard let url = URL(string: raw), let host = url.host else {
      phase = .failed(.malformedResponse)
      return
    }
    let resolved = ResolvedServer(
      instanceID: UUID(),
      host: host,
      port: url.port ?? 80,
      apiVersion: "v1",
      serverVersion: "unknown"
    )
    await requestCode(for: resolved)
  }

  /// Resets to the discovering phase and restarts discovery.
  func reset() {
    pollTask?.cancel()
    pollTask = nil
    phase = .discovering([])
    startDiscovery()
  }

  private func requestCode(for server: ResolvedServer) async {
    phase = .requestingCode(server)
    let client = PairingClient(server: server)
    do {
      let challenge = try await client.requestCode(
        deviceName: deviceName(),
        platform: .iOS
      )
      phase = .awaitingApproval(challenge, server)
      startPolling(challenge: challenge, server: server)
    } catch let error as PairingError {
      phase = .failed(error)
    } catch {
      phase = .failed(.malformedResponse)
    }
  }

  private func startPolling(challenge: PairingChallenge, server: ResolvedServer) {
    pollTask?.cancel()
    pollTask = Task { [weak self] in
      let client = PairingClient(server: server)
      do {
        let session = try await client.awaitApproval(challenge)
        await self?.appState?.signedIn(session)
      } catch let error as PairingError {
        self?.phase = .failed(error)
      } catch {
        self?.phase = .failed(.malformedResponse)
      }
    }
  }

  private func deviceName() -> String {
    UIDevice.current.name
  }
}
