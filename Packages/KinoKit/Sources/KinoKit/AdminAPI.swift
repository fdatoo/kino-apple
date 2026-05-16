import Foundation
import KinoKitGenerated

/// Pending pairing summary visible to admins.
public typealias AdminPairingSummary = Components.Schemas.AdminPairingSummary

/// Response returned after approving a pending pairing.
public typealias ApprovePairingResponse = Components.Schemas.ApprovePairingResponse

/// Administrative API wrapper.
public struct AdminAPI: Sendable {
  private let transport: KinoTransport

  /// Creates an admin API bound to a transport.
  public init(transport: KinoTransport) {
    self.transport = transport
  }

  /// Lists pending pairing requests visible to an admin.
  public func listPendingPairings() async throws -> [AdminPairingSummary] {
    let output = try await transport.makeClient().listPairings()

    switch output {
    case .ok(let response):
      return try response.body.json.pairings
    case .unauthorized:
      throw ErrorMapper.map(httpStatus: 401, body: nil)
    case .internalServerError:
      throw ErrorMapper.map(httpStatus: 500, body: nil)
    case .undocumented(let statusCode, _):
      throw ErrorMapper.map(httpStatus: statusCode, body: nil)
    }
  }

  /// Approves a pending pairing request.
  public func approve(pairingID: UUID) async throws -> ApprovePairingResponse {
    let output = try await transport.makeClient().approvePairing(
      path: .init(pairingId: pairingID.uuidString)
    )

    switch output {
    case .ok(let response):
      return try response.body.json
    case .unauthorized:
      throw ErrorMapper.map(httpStatus: 401, body: nil)
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

  /// Rejects a pending pairing request.
  public func reject(pairingID: UUID) async throws {
    let output = try await transport.makeClient().rejectPairing(
      path: .init(pairingId: pairingID.uuidString)
    )

    switch output {
    case .noContent:
      return
    case .unauthorized:
      throw ErrorMapper.map(httpStatus: 401, body: nil)
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
