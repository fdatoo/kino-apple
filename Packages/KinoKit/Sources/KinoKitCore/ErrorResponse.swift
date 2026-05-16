/// Error body returned by Kino API endpoints that use the shared error schema.
public struct ErrorResponse: Sendable, Hashable, Codable {
  /// Human-readable server error message.
  public let error: String

  /// Creates an API error response value.
  public init(error: String) {
    self.error = error
  }
}
