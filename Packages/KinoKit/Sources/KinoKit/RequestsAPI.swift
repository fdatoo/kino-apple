import Foundation
import KinoKitGenerated

/// Media request projection returned by Kino.
public typealias RequestSummary = Components.Schemas.Request

/// Media request detail returned after request creation.
public typealias RequestDetail = Components.Schemas.RequestDetail

/// Media request API wrapper.
public struct RequestsAPI: Sendable {
  private let transport: KinoTransport

  /// Creates a requests API bound to a transport.
  public init(transport: KinoTransport) {
    self.transport = transport
  }

  /// Creates a request for a TMDB-backed media identity.
  public func create(kind: DiscoverKind, tmdbID: Int) async throws -> RequestDetail {
    let output = try await transport.makeClient().createRequest(
      body: .json(.init(target: "tmdb:\(kind.rawValue):\(tmdbID)"))
    )

    switch output {
    case .created(let response):
      return try response.body.json
    case .internalServerError:
      throw ErrorMapper.map(httpStatus: 500, body: nil)
    case .undocumented(let statusCode, _):
      throw ErrorMapper.map(httpStatus: statusCode, body: nil)
    }
  }

  /// Lists media requests visible to the current session.
  public func list() async throws -> [RequestSummary] {
    let output = try await transport.makeClient().listRequests()

    switch output {
    case .ok(let response):
      return try response.body.json.requests
    case .badRequest:
      throw ErrorMapper.map(httpStatus: 400, body: nil)
    case .internalServerError:
      throw ErrorMapper.map(httpStatus: 500, body: nil)
    case .undocumented(let statusCode, _):
      throw ErrorMapper.map(httpStatus: statusCode, body: nil)
    }
  }
}
