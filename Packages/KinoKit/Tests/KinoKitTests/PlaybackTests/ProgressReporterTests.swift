import XCTest

@testable import KinoKit

final class ProgressReporterTests: XCTestCase {
  func test_reportThrottlesProgressToTenSecondCadence() async {
    let recorder = CallbackRecorder()
    let reporter = ProgressReporter(
      onProgress: { seconds in await recorder.recordProgress(seconds) },
      onWatched: { await recorder.recordWatched() }
    )

    await reporter.report(seconds: 0, totalSeconds: 100)
    await reporter.report(seconds: 5, totalSeconds: 100)
    await reporter.report(seconds: 10, totalSeconds: 100)
    await reporter.report(seconds: 19.9, totalSeconds: 100)
    await reporter.report(seconds: 20, totalSeconds: 100)

    let progresses = await recorder.progresses
    XCTAssertEqual(progresses, [0, 10, 20])
  }

  func test_reportFiresWatchedAtThresholdOnce() async {
    let recorder = CallbackRecorder()
    let reporter = ProgressReporter(
      onProgress: { seconds in await recorder.recordProgress(seconds) },
      onWatched: { await recorder.recordWatched() }
    )

    await reporter.report(seconds: 89, totalSeconds: 100)
    await reporter.report(seconds: 90, totalSeconds: 100)
    await reporter.report(seconds: 95, totalSeconds: 100)

    let watchedCount = await recorder.watchedCount
    XCTAssertEqual(watchedCount, 1)
  }

  func test_reportDoesNotFireWatchedForUnknownRuntime() async {
    let recorder = CallbackRecorder()
    let reporter = ProgressReporter(
      onProgress: { seconds in await recorder.recordProgress(seconds) },
      onWatched: { await recorder.recordWatched() }
    )

    await reporter.report(seconds: 90, totalSeconds: 0)

    let watchedCount = await recorder.watchedCount
    XCTAssertEqual(watchedCount, 0)
  }

  func test_flushAlwaysReportsProvidedSeconds() async {
    let recorder = CallbackRecorder()
    let reporter = ProgressReporter(
      onProgress: { seconds in await recorder.recordProgress(seconds) },
      onWatched: { await recorder.recordWatched() }
    )

    await reporter.report(seconds: 0, totalSeconds: 100)
    await reporter.flush(seconds: 3)
    await reporter.flush(seconds: 3)

    let progresses = await recorder.progresses
    XCTAssertEqual(progresses, [0, 3, 3])
  }
}

private actor CallbackRecorder {
  private(set) var progresses: [Double] = []
  private(set) var watchedCount = 0

  func recordProgress(_ seconds: Double) {
    progresses.append(seconds)
  }

  func recordWatched() {
    watchedCount += 1
  }
}
