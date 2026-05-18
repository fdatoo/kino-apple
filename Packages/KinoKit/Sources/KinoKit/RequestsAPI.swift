import Foundation
import KinoKitGenerated

/// Media request projection returned by Kino.
public typealias RequestSummary = Components.Schemas.Request

/// Media request detail returned after request creation.
public typealias RequestDetail = Components.Schemas.RequestDetail

/// Durable state-change event recorded for a request.
public typealias RequestStatusEvent = Components.Schemas.RequestStatusEvent

/// Durable request state.
public typealias RequestState = Components.Schemas.RequestState

/// Media request API wrapper.
public struct RequestsAPI: Sendable {
  private let transport: KinoTransport

  /// Creates a requests API bound to a transport.
  public init(transport: KinoTransport) {
    self.transport = transport
  }

  /// Creates a media request from a free-text query and optional canonical identity.
  ///
  /// `query` is the human-readable display target (e.g. `"Mr Robot 2015"`). When
  /// `canonicalIdentityID` is supplied (e.g. `"tmdb:series:37680"` from a discover
  /// candidate), the server skips TMDB lookup and creates the request directly in
  /// the `resolved` state. Otherwise the server parses `query` and searches TMDB
  /// itself.
  public func create(query: String, canonicalIdentityID: String? = nil) async throws
    -> RequestDetail
  {
    let output = try await transport.makeClient().createRequest(
      body: .json(.init(canonicalIdentityId: canonicalIdentityID, target: query))
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

  /// Fetches the full detail projection for a single request.
  public func get(id: UUID) async throws -> RequestDetail {
    let output = try await transport.makeClient().getRequest(
      path: .init(id: id.uuidString)
    )

    switch output {
    case .ok(let response):
      return try response.body.json
    case .badRequest:
      throw ErrorMapper.map(httpStatus: 400, body: nil)
    case .notFound:
      throw ErrorMapper.map(httpStatus: 404, body: nil)
    case .internalServerError:
      throw ErrorMapper.map(httpStatus: 500, body: nil)
    case .undocumented(let statusCode, _):
      throw ErrorMapper.map(httpStatus: statusCode, body: nil)
    }
  }

  /// Cancels a request and returns the refreshed detail after the state transition.
  ///
  /// The server's cancel endpoint returns a `RequestDetail` body on `200 OK`,
  /// so no follow-up GET is required.
  public func cancel(id: UUID) async throws -> RequestDetail {
    let output = try await transport.makeClient().cancelRequest(
      path: .init(id: id.uuidString)
    )

    switch output {
    case .ok(let response):
      return try response.body.json
    case .badRequest:
      throw ErrorMapper.map(httpStatus: 400, body: nil)
    case .notFound:
      throw ErrorMapper.map(httpStatus: 404, body: nil)
    case .conflict:
      throw ErrorMapper.map(httpStatus: 409, body: nil)
    case .internalServerError:
      throw ErrorMapper.map(httpStatus: 500, body: nil)
    case .undocumented(let statusCode, _):
      throw ErrorMapper.map(httpStatus: statusCode, body: nil)
    }
  }
}
