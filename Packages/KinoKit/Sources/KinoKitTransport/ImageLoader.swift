import Foundation
import KinoKitCore

/// Loads image bytes through URLSession, adding Kino authorization only when requested.
public actor ImageLoader {
  private let session: URLSession
  private let token: @Sendable () -> String?

  /// Creates an image loader with a 256 MB disk-backed URL cache.
  public init(token: @escaping @Sendable () -> String? = { nil }) {
    self.session = Self.makeDefaultSession()
    self.token = token
  }

  /// Creates an image loader using a caller-provided session.
  public init(session: URLSession, token: @escaping @Sendable () -> String? = { nil }) {
    self.session = session
    self.token = token
  }

  /// Loads image bytes, stamping authorization only for internal Kino URLs.
  public func loadImage(url: URL, isInternal: Bool) async throws -> Data {
    var request = URLRequest(url: url)
    if isInternal, let token = token() {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    do {
      let (data, response) = try await session.data(for: request)
      guard let response = response as? HTTPURLResponse else {
        throw KinoError.transport(URLError(.badServerResponse))
      }
      guard (200..<300).contains(response.statusCode) else {
        throw ErrorMapper.map(httpStatus: response.statusCode, body: nil)
      }
      return data
    } catch let error as KinoError {
      throw error
    } catch let error as URLError {
      throw ErrorMapper.mapTransport(error)
    } catch {
      throw ErrorMapper.mapTransport(error)
    }
  }

  private static func makeDefaultSession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    configuration.urlCache = URLCache(
      memoryCapacity: 0,
      diskCapacity: 256 * 1024 * 1024,
      directory: nil
    )
    return URLSession(configuration: configuration)
  }
}
