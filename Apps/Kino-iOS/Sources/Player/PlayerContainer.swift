import AVFoundation
import KinoKit
import SwiftUI
import os

/// Owns the `PlaybackCoordinator` lifecycle and presents `AVPlayerViewController` full-screen.
struct PlayerContainer: View {
  let item: MediaItem

  @Environment(\.kinoClient) private var client
  @Environment(\.dismiss) private var dismiss
  @State private var player: AVPlayer?
  @State private var coordinator: PlaybackCoordinator?
  @State private var error: KinoError?

  private let logger = Logger(subsystem: "kino.ios", category: "player")

  @State private var statusObserver: NSKeyValueObservation?

  private func observePlayerItemStatus(_ playerItem: AVPlayerItem) {
    statusObserver = playerItem.observe(\.status, options: [.new, .initial]) { [logger] item, _ in
      switch item.status {
      case .readyToPlay:
        logger.info("playerItem.status: readyToPlay")
      case .failed:
        logger.error(
          "playerItem.status: failed — error=\(String(describing: item.error), privacy: .public)"
        )
      case .unknown:
        logger.info("playerItem.status: unknown")
      @unknown default:
        logger.info("playerItem.status: @unknown")
      }
    }
  }

  private func logPlayerItemFailures(_ playerItem: AVPlayerItem) {
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { [logger] note in
      let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey]
      logger.error("AVPlayer failed to play to end: \(String(describing: err), privacy: .public)")
    }
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemNewErrorLogEntry,
      object: playerItem,
      queue: .main
    ) { [logger] _ in
      guard let entry = (playerItem.errorLog()?.events.last) else { return }
      logger.error(
        "AVPlayer error: status=\(entry.errorStatusCode), domain=\(entry.errorDomain, privacy: .public), comment=\(entry.errorComment ?? "-", privacy: .public), uri=\(entry.uri ?? "-", privacy: .public)"
      )
    }
  }

  var body: some View {
    Group {
      if let player {
        AVPlayerViewControllerRepresentable(player: player)
      } else if let error {
        errorOverlay(error)
      } else {
        ProgressView()
          .controlSize(.large)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.black)
      }
    }
    .ignoresSafeArea()
    .task {
      await start()
    }
    .onDisappear {
      Task { await coordinator?.stopReporting() }
    }
  }

  @ViewBuilder
  private func errorOverlay(_ error: KinoError) -> some View {
    VStack(spacing: 16) {
      Text("Playback failed").font(.headline)
      Text(error.localizedDescription).font(.caption).foregroundStyle(.secondary)
      Button("Retry") { Task { await start() } }
        .buttonStyle(.borderedProminent)
        .tint(.white)
        .foregroundStyle(.black)
      Button("Close") { dismiss() }
        .foregroundStyle(.white)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
  }

  private func start() async {
    // Reset any prior state before constructing a new coordinator/player.
    if let existing = coordinator {
      await existing.stopReporting()
      coordinator = nil
    }
    player?.pause()
    player = nil

    guard let client else { return }
    error = nil
    let token = client.session.token
    let coord = PlaybackCoordinator(
      reporter: client.playback,
      item: item,
      capabilities: .iOS17Default,
      baseURL: client.session.baseURL,
      token: { token }
    )
    coordinator = coord
    do {
      let plan = try await coord.prepare()
      logger.info("playback plan: \(String(describing: plan.source), privacy: .public)")
      let playerItem = coord.makePlayerItem(plan)
      if let urlAsset = playerItem.asset as? AVURLAsset {
        logger.info("AVURLAsset URL: \(urlAsset.url.absoluteString, privacy: .public)")
      }
      logPlayerItemFailures(playerItem)
      observePlayerItemStatus(playerItem)
      let p = AVPlayer(playerItem: playerItem)
      player = p
      await coord.startReporting(player: p)
      p.play()
    } catch let e as KinoError {
      logger.error("Playback prepare failed: \(String(describing: e), privacy: .public)")
      self.error = e
    } catch {
      logger.error(
        "Playback prepare decoding failed: \(String(describing: error), privacy: .public)")
      self.error = .decoding(error)
    }
  }
}
