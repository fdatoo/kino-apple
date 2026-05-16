import Foundation

/// Error surfaced by KinoKit operations.
public enum KinoError: Error, Sendable {
  /// Transport-level failure before a server response could be handled.
  case transport(URLError)

  /// Non-success server response with an optional decoded body.
  case server(status: Int, body: ErrorResponse?)

  /// Missing, expired, or revoked authorization.
  case unauthorized

  /// Pairing flow failure.
  case pairing(PairingError)

  /// Playback planning or fallback failure.
  case playback(PlaybackError)

  /// Response decoding failure, including errors wrapped by the OpenAPI runtime.
  case decoding(any Error)
}

extension KinoError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .transport(let error):
      return "Network error: \(error.localizedDescription)"
    case .server(let status, let body):
      return "Server returned \(status): \(body?.error ?? "")"
    case .unauthorized:
      return "Session is no longer valid; please re-pair."
    case .pairing(let error):
      return error.localizedDescription
    case .playback(let error):
      return error.localizedDescription
    case .decoding(let error):
      return "Response decoding failed: \(error)"
    }
  }
}

/// Error surfaced by the client pairing flow.
public enum PairingError: Error, Sendable, LocalizedError {
  /// The pairing code expired before approval.
  case expired

  /// The server operator rejected the pairing request.
  case rejected

  /// The server generated a code that collided with an active pairing.
  case codeCollision

  /// The server returned a pairing response that KinoKit could not interpret.
  case malformedResponse

  public var errorDescription: String? {
    switch self {
    case .expired:
      return "Pairing code expired."
    case .rejected:
      return "Pairing was rejected by the admin."
    case .codeCollision:
      return "Server returned a duplicate code; retry."
    case .malformedResponse:
      return "Server returned an unexpected pairing response."
    }
  }
}

/// Error surfaced by playback planning and fallback handling.
public enum PlaybackError: Error, Sendable, LocalizedError {
  /// No source or transcode output can play on the current device.
  case noPlayablePlan

  /// Playback failed after trying every available fallback.
  case fallbackExhausted

  /// Playback planning was requested without client capabilities.
  case capabilitiesMissing

  public var errorDescription: String? {
    switch self {
    case .noPlayablePlan:
      return "No playable variant for this item on this device."
    case .fallbackExhausted:
      return "Playback failed after all fallbacks."
    case .capabilitiesMissing:
      return "Client capabilities were not provided."
    }
  }
}
