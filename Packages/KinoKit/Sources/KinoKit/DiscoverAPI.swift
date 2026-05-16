import Foundation
import KinoKitGenerated

/// Media kind accepted by discover and TMDB-backed request APIs.
public typealias DiscoverKind = Components.Schemas.DiscoverKind

/// TMDB-backed discover response.
public typealias DiscoverResponse = Components.Schemas.DiscoverResponse

/// TMDB-backed discovery API wrapper.
public struct DiscoverAPI: Sendable {
  private let transport: KinoTransport

  /// Creates a discover API bound to a transport.
  public init(transport: KinoTransport) {
    self.transport = transport
  }

  /// Searches TMDB candidates through the Kino server.
  public func search(q: String, kind: DiscoverKind, page: Int? = nil)
    async throws
    -> DiscoverResponse
  {
    let output = try await transport.makeClient().discover(
      query: .init(q: q, kind: kind, page: page.map(Int32.init))
    )

    switch output {
    case .ok(let response):
      return try response.body.json
    case .badRequest:
      throw ErrorMapper.map(httpStatus: 400, body: nil)
    case .unauthorized:
      throw ErrorMapper.map(httpStatus: 401, body: nil)
    case .internalServerError:
      throw ErrorMapper.map(httpStatus: 500, body: nil)
    case .badGateway:
      throw ErrorMapper.map(httpStatus: 502, body: nil)
    case .serviceUnavailable:
      throw ErrorMapper.map(httpStatus: 503, body: nil)
    case .undocumented(let statusCode, _):
      throw ErrorMapper.map(httpStatus: statusCode, body: nil)
    }
  }
}
