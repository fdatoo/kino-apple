import SwiftUI

/// A single poster image in 2:3 aspect ratio with a drop shadow.
struct PosterCell: View {
  let url: URL?
  let title: String?

  var body: some View {
    KinoAsyncImage(url: url, isInternal: true, cornerRadius: 8)
      .aspectRatio(2.0 / 3.0, contentMode: .fit)
      .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
  }
}
