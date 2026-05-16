import Foundation
import OpenAPIURLSession

@_exported import struct KinoKitGenerated.Client

/// URLSession-backed transport factory for the generated Kino API client.
public struct KinoTransport: Sendable {
  /// Session used by generated API calls and image loading.
  public let urlSession: URLSession

  private let baseURL: URL
  private let token: @Sendable () -> String?

  /// Creates a transport bound to a real Kino server.
  public static func live(
    baseURL: URL,
    token: @escaping @Sendable () -> String?
  ) -> KinoTransport {
    let configuration = URLSessionConfiguration.default
    configuration.urlCache = URLCache(
      memoryCapacity: 0,
      diskCapacity: 256 * 1024 * 1024,
      directory: nil
    )
    return KinoTransport(
      urlSession: URLSession(configuration: configuration),
      baseURL: baseURL,
      token: token
    )
  }

  /// Creates a transport around a caller-supplied session for tests.
  public static func mock(
    _ session: URLSession,
    token: @escaping @Sendable () -> String? = { nil }
  ) -> KinoTransport {
    KinoTransport(
      urlSession: session,
      baseURL: URL(string: "http://stub.local")!,
      token: token
    )
  }

  /// Builds the generated OpenAPI client with URLSession transport and auth middleware.
  public func makeClient() -> Client {
    Client(
      serverURL: baseURL,
      transport: URLSessionTransport(configuration: .init(session: urlSession)),
      middlewares: [AuthInterceptor(token: token)]
    )
  }
}
