import Foundation

/// Authorized Kino API facade used by app targets.
public final class KinoClient: Sendable {
  /// Session used to authorize requests.
  public let session: AuthorizedSession

  private let transport: KinoTransport

  /// Creates a client bound to an authorized session.
  public init(session: AuthorizedSession, transport: KinoTransport? = nil) {
    self.session = session
    self.transport = transport ?? .live(baseURL: session.baseURL, token: { session.token })
  }

  /// Library catalog operations.
  public var library: LibraryAPI {
    LibraryAPI(transport: transport)
  }

  /// Media request operations.
  public var requests: RequestsAPI {
    RequestsAPI(transport: transport)
  }

  /// TMDB-backed discovery operations.
  public var discover: DiscoverAPI {
    DiscoverAPI(transport: transport)
  }

  /// Playback progress operations.
  public var playback: PlaybackAPI {
    PlaybackAPI(transport: transport)
  }

  /// Administrative operations when the session has admin privileges.
  public var admin: AdminAPI? {
    session.isAdmin ? AdminAPI(transport: transport) : nil
  }

  /// Image loader using the session-bound transport and token.
  public var images: ImageLoader {
    ImageLoader(session: transport.urlSession, token: { self.session.token })
  }
}
