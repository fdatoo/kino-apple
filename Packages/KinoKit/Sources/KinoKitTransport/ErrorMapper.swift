import Foundation
import KinoKitCore

/// Converts transport and HTTP failures into KinoKit's typed error surface.
public enum ErrorMapper {
  /// Maps a non-success HTTP status and optional decoded error body.
  public static func map(httpStatus: Int, body: ErrorResponse?) -> KinoError {
    if httpStatus == 401 {
      return .unauthorized
    }
    return .server(status: httpStatus, body: body)
  }

  /// Maps a lower-level request failure.
  public static func mapTransport(_ error: any Error) -> KinoError {
    if let error = error as? KinoError {
      return error
    }
    if let error = error as? URLError {
      return .transport(error)
    }
    return .decoding(error)
  }
}
