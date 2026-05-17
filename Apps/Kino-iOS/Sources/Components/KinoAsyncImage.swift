import KinoKit
import SwiftUI

// TODO(M3.3 or later): inject auth header into URLRequest when isInternal == true

/// Async image wrapper with rounded clip and a subtle stroke overlay for the Kino aesthetic.
///
/// `isInternal` is reserved for future auth-token injection when server-hosted images require
/// authentication headers. For now all URLs load via `URLSession.shared`.
struct KinoAsyncImage: View {
  let url: URL?
  let isInternal: Bool
  var cornerRadius: CGFloat = 8

  var body: some View {
    AsyncImage(url: url, transaction: .init(animation: .easeOut(duration: 0.18))) { phase in
      switch phase {
      case .success(let image):
        image.resizable().aspectRatio(contentMode: .fill)
      case .failure, .empty:
        Rectangle().fill(Color(.tertiarySystemFill))
      @unknown default:
        Rectangle().fill(Color(.tertiarySystemFill))
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius)
        .stroke(
          LinearGradient(
            colors: [.white.opacity(0.12), .clear, .black.opacity(0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 0.5
        )
    )
  }
}
