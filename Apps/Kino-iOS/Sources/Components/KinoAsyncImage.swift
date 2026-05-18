import KinoKit
import SwiftUI
import UIKit

/// Authenticated async image with rounded clip and a subtle stroke overlay for the Kino aesthetic.
///
/// `isInternal` controls whether the bearer token from the active `KinoClient` is sent —
/// `true` for kino-server-hosted images (poster/backdrop endpoints require auth);
/// `false` for off-server URLs (e.g., TMDB).
struct KinoAsyncImage: View {
  let url: URL?
  let isInternal: Bool
  var cornerRadius: CGFloat = 8

  @Environment(\.kinoClient) private var client
  @State private var image: UIImage?
  @State private var loadFailed = false

  var body: some View {
    Group {
      if let image {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)
      } else {
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
    .task(id: url) { await load() }
  }

  private func load() async {
    image = nil
    loadFailed = false
    guard let url, let client else { return }
    do {
      let data = try await client.images.loadImage(url: url, isInternal: isInternal)
      if let decoded = UIImage(data: data) {
        await MainActor.run { self.image = decoded }
      } else {
        await MainActor.run { self.loadFailed = true }
      }
    } catch {
      await MainActor.run { self.loadFailed = true }
    }
  }
}
