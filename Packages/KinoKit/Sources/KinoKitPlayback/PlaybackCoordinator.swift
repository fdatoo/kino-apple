import AVFoundation
import Foundation
import KinoKitCore
import os

/// Coordinates playback planning, player item creation, progress reporting, and fallback.
public actor PlaybackCoordinator {
  private let reporterClient: any PlaybackReporting
  private let item: MediaItem
  private let capabilities: ClientCapabilities
  private let logger = Logger(subsystem: "kino.kit", category: "playback")
  private var plan: PlaybackPlan?
  private var progressReporter: ProgressReporter?
  private var lastPlanKind: PlaybackPlan.Source?
  private var lastReportedSeconds: Double?
  private var playerObservation: PlayerObservation?

  /// Creates a playback coordinator for one item and capability set.
  public init(
    reporter: any PlaybackReporting,
    item: MediaItem,
    capabilities: ClientCapabilities
  ) {
    self.reporterClient = reporter
    self.item = item
    self.capabilities = capabilities
  }

  /// Prepares the initial playback plan.
  public func prepare() async throws -> PlaybackPlan {
    let plan = VariantChooser.choose(item: item, capabilities: capabilities)
    self.plan = plan
    self.lastPlanKind = plan.source
    logger.debug("Prepared playback plan")
    return plan
  }

  /// Builds an AVPlayer item for a playback plan.
  public nonisolated func makePlayerItem(_ plan: PlaybackPlan) -> AVPlayerItem {
    AVPlayerItem(url: url(for: plan.source))
  }

  /// Starts periodic progress reporting from an AVPlayer.
  public func startReporting(player: AVPlayer) {
    stopObservingPlayer()

    let itemID = item.id
    let client = reporterClient
    let logger = logger
    let reporter = ProgressReporter(
      onProgress: { seconds in
        do {
          try await client.reportProgress(itemID: itemID, seconds: seconds)
        } catch {
          logger.error(
            "Playback progress report failed: \(String(describing: error), privacy: .public)")
        }
      },
      onWatched: {
        do {
          try await client.markWatched(itemID: itemID)
        } catch {
          logger.error(
            "Playback watched report failed: \(String(describing: error), privacy: .public)")
        }
      }
    )

    self.progressReporter = reporter
    let interval = CMTime(seconds: 1, preferredTimescale: 600)
    let totalSeconds = item.runtimeSeconds.map(Double.init) ?? 0
    let observer = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      [weak self] time in
      let seconds = time.seconds
      Task {
        await self?.recordReportedSeconds(seconds)
        await reporter.report(seconds: seconds, totalSeconds: totalSeconds)
      }
    }
    playerObservation = PlayerObservation(player: player, observer: observer)
  }

  /// Stops periodic progress reporting and flushes the last observed playback position.
  public func stopReporting() async {
    stopObservingPlayer()
    guard let progressReporter else { return }

    await progressReporter.flush(seconds: lastReportedSeconds ?? 0)
    self.progressReporter = nil
  }

  /// Handles a player failure by returning the next fallback plan or throwing when exhausted.
  public func handlePlayerFailure(_ error: any Error) async throws -> PlaybackPlan {
    guard let current = lastPlanKind else {
      logger.error("Playback fallback exhausted before an initial plan existed")
      throw KinoError.playback(.fallbackExhausted)
    }

    switch current {
    case .hlsTranscodeOutput:
      let live = livePlan()
      setFallbackPlan(live)
      logger.debug("Falling back from cached HLS output to live transcode")
      return live

    case .directByteRange:
      if let output = bestTranscodeOutput(item.transcodeOutputs) {
        let hls = PlaybackPlan(
          source: .hlsTranscodeOutput(masterURL: output.masterURL, outputID: output.id),
          subtitleTracks: item.subtitleTracks,
          resumeAt: item.resumeAt
        )
        setFallbackPlan(hls)
        logger.debug("Falling back from direct source to cached HLS output")
        return hls
      }

      let live = livePlan()
      setFallbackPlan(live)
      logger.debug("Falling back from direct source to live transcode")
      return live

    case .hlsLive:
      logger.error("Playback fallback exhausted after live transcode failure")
      throw KinoError.playback(.fallbackExhausted)
    }
  }

  private nonisolated func url(for source: PlaybackPlan.Source) -> URL {
    switch source {
    case .directByteRange(let url):
      return url
    case .hlsTranscodeOutput(let masterURL, _):
      return masterURL
    case .hlsLive(let masterURL, _):
      return masterURL
    }
  }

  private func recordReportedSeconds(_ seconds: Double) {
    lastReportedSeconds = seconds
  }

  private func setFallbackPlan(_ plan: PlaybackPlan) {
    self.plan = plan
    self.lastPlanKind = plan.source
  }

  private func livePlan() -> PlaybackPlan {
    let profile = VariantChooser.liveProfile(for: capabilities)
    return PlaybackPlan(
      source: .hlsLive(
        masterURL: VariantChooser.liveMasterURL(item: item, profile: profile), profile: profile),
      subtitleTracks: item.subtitleTracks,
      resumeAt: item.resumeAt
    )
  }

  private func bestTranscodeOutput(_ outputs: [TranscodeOutput]) -> TranscodeOutput? {
    outputs.sorted {
      let left = ($0.vmafTarget ?? 0, $0.height, $0.createdAt)
      let right = ($1.vmafTarget ?? 0, $1.height, $1.createdAt)
      return left > right
    }.first
  }

  private func stopObservingPlayer() {
    playerObservation?.cancel()
    playerObservation = nil
  }
}

private final class PlayerObservation: @unchecked Sendable {
  private weak var player: AVPlayer?
  private let observer: Any

  init(player: AVPlayer, observer: Any) {
    self.player = player
    self.observer = observer
  }

  func cancel() {
    player?.removeTimeObserver(observer)
  }

  deinit {
    cancel()
  }
}
