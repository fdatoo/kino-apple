import Foundation

/// Throttles playback progress callbacks and emits the watched event at completion threshold.
public actor ProgressReporter {
  private var lastSentSeconds: Double = -.infinity
  private var didMarkWatched = false
  private let interval: TimeInterval = 10
  private let watchedThreshold: Double = 0.9
  private let onProgress: @Sendable (TimeInterval) async -> Void
  private let onWatched: @Sendable () async -> Void

  /// Creates a reporter with progress and watched callbacks.
  public init(
    onProgress: @escaping @Sendable (TimeInterval) async -> Void,
    onWatched: @escaping @Sendable () async -> Void
  ) {
    self.onProgress = onProgress
    self.onWatched = onWatched
  }

  /// Reports playback position, throttling progress to a ten-second cadence.
  public func report(seconds: Double, totalSeconds: Double) async {
    if seconds - lastSentSeconds >= interval {
      lastSentSeconds = seconds
      await onProgress(seconds)
    }

    if !didMarkWatched, totalSeconds > 0, seconds / totalSeconds >= watchedThreshold {
      didMarkWatched = true
      await onWatched()
    }
  }

  /// Forces a final progress callback at the provided playback position.
  public func flush(seconds: Double) async {
    lastSentSeconds = seconds
    await onProgress(seconds)
  }
}
