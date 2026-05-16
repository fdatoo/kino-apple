import Foundation
import OpenAPIRuntime

/// ISO 8601 transcoder that accepts both fractional-seconds and whole-seconds
/// timestamps. Surfaced by manual probe acceptance: the kino server emits
/// `2026-05-16T12:25:23.206406Z` (microseconds), but the runtime's default
/// `ISO8601DateTranscoder` only accepts whole-seconds and throws
/// `DecodingError: dataCorrupted`.
///
/// Encodes with fractional seconds for maximum interop. Decodes by trying
/// fractional-seconds first, then falling back to plain ISO 8601.
public struct TolerantISO8601DateTranscoder: DateTranscoder {
  private let withFractional: ISO8601DateTranscoder
  private let plain: ISO8601DateTranscoder

  public init() {
    self.withFractional = ISO8601DateTranscoder(options: [
      .withInternetDateTime, .withFractionalSeconds,
    ])
    self.plain = ISO8601DateTranscoder()
  }

  public func encode(_ date: Date) throws -> String {
    try withFractional.encode(date)
  }

  public func decode(_ dateString: String) throws -> Date {
    if let date = try? withFractional.decode(dateString) {
      return date
    }
    return try plain.decode(dateString)
  }
}
