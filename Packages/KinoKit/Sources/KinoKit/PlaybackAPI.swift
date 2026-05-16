import Foundation
import KinoKitGenerated

/// Playback progress API wrapper.
public struct PlaybackAPI: PlaybackReporting, Sendable {
  private let transport: KinoTransport

  /// Creates a playback API bound to a transport.
  public init(transport: KinoTransport) {
    self.transport = transport
  }

  /// Reports playback progress for an item.
  public func reportProgress(itemID: UUID, seconds: Double) async throws {
    let output = try await transport.makeClient().recordProgress(
      body: .json(
        .init(
          mediaItemId: itemID.uuidString,
          positionSeconds: Int64(seconds.rounded(.down))
        )
      )
    )

    switch output {
    case .noContent:
      return
    case .badRequest:
      throw ErrorMapper.map(httpStatus: 400, body: nil)
    case .internalServerError:
      throw ErrorMapper.map(httpStatus: 500, body: nil)
    case .undocumented(let statusCode, _):
      throw ErrorMapper.map(httpStatus: statusCode, body: nil)
    }
  }

  /// Marks an item watched for the current user.
  public func markWatched(itemID: UUID) async throws {
    let output = try await transport.makeClient().markWatched(
      path: .init(mediaItemId: itemID.uuidString)
    )

    switch output {
    case .noContent:
      return
    case .internalServerError:
      throw ErrorMapper.map(httpStatus: 500, body: nil)
    case .undocumented(let statusCode, _):
      throw ErrorMapper.map(httpStatus: statusCode, body: nil)
    }
  }
}
