import XCTest

@testable import KinoKit

final class DateTranscoderTests: XCTestCase {
  /// Pin the wire form the kino server actually emits (RFC 3339 with
  /// fractional seconds in microsecond precision). Surfaced by manual probe
  /// acceptance.
  func test_decodesFractionalSecondsTimestamp() throws {
    let transcoder = TolerantISO8601DateTranscoder()
    let date = try transcoder.decode("2026-05-16T12:25:23.206406Z")

    let expected = ISO8601DateFormatter()
    expected.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    XCTAssertEqual(date, expected.date(from: "2026-05-16T12:25:23.206406Z"))
  }

  /// Falls back gracefully to whole-seconds ISO 8601 when fractional seconds
  /// are absent (some clients/servers strip them).
  func test_decodesWholeSecondsTimestamp() throws {
    let transcoder = TolerantISO8601DateTranscoder()
    let date = try transcoder.decode("2026-05-16T12:25:23Z")

    let expected = ISO8601DateFormatter()
    XCTAssertEqual(date, expected.date(from: "2026-05-16T12:25:23Z"))
  }

  /// Encoded form always includes fractional seconds (max interop with peers
  /// that require them).
  func test_encodesWithFractionalSeconds() throws {
    let transcoder = TolerantISO8601DateTranscoder()
    let date = Date(timeIntervalSince1970: 1_736_000_000.123456)
    let encoded = try transcoder.encode(date)
    XCTAssertTrue(encoded.contains("."), "encoded form should carry fractional seconds: \(encoded)")
    XCTAssertTrue(encoded.hasSuffix("Z"), "encoded form should end with Z: \(encoded)")
  }

  func test_decodeRejectsGarbage() {
    let transcoder = TolerantISO8601DateTranscoder()
    XCTAssertThrowsError(try transcoder.decode("not-a-date"))
  }
}
