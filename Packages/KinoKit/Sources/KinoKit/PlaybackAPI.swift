import Foundation
import KinoKitGenerated

/// An in-progress playback item returned by the server.
public typealias InProgressItem = Components.Schemas.InProgressItem

/// A library item summary embedded in playback and catalog responses.
public typealias LibraryItemSummary = Components.Schemas.LibraryItemSummary

/// Paginated list of in-progress playback items.
public typealias PlaybackProgressList = Components.Schemas.PlaybackProgressList

/// Playback progress API wrapper.
public struct PlaybackAPI: PlaybackReporting, Sendable {
  private let transport: KinoTransport

  /// Creates a playback API bound to a transport.
  public init(transport: KinoTransport) {
    self.transport = transport
  }

  /// Lists in-progress items for the current user, most recently updated first.
  public func listInProgress(limit: Int? = nil) async throws -> [InProgressItem] {
    let output = try await transport.makeClient().listProgress(
      query: .init(limit: limit.map(Int32.init))
    )

    switch output {
    case .ok(let response):
      return try response.body.json.items
    case .unauthorized:
      throw ErrorMapper.map(httpStatus: 401, body: nil)
    case .internalServerError:
      throw ErrorMapper.map(httpStatus: 500, body: nil)
    case .undocumented(let statusCode, _):
      throw ErrorMapper.map(httpStatus: statusCode, body: nil)
    }
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
