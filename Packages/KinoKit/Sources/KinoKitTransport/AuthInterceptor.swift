import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Adds bearer authorization to generated-client requests when a token exists.
public struct AuthInterceptor: ClientMiddleware {
  private let token: @Sendable () -> String?

  /// Creates an interceptor that asks for the current bearer token per request.
  public init(token: @escaping @Sendable () -> String?) {
    self.token = token
  }

  public func intercept(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    var request = request
    if let token = token() {
      request.headerFields[.authorization] = "Bearer \(token)"
    }
    return try await next(request, body, baseURL)
  }
}
