import SwiftUI

/// Adaptive lazy grid of poster cells; calls `onAppearLast` when the last item appears for pagination.
struct PosterGrid<Item: Identifiable>: View {
  let items: [Item]
  let poster: (Item) -> URL?
  let onTap: (Item) -> Void
  let onAppearLast: () -> Void

  private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

  var body: some View {
    LazyVGrid(columns: columns, spacing: 10) {
      ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
        Button {
          onTap(item)
        } label: {
          PosterCell(url: poster(item), title: nil)
        }
        .buttonStyle(.plain)
        .onAppear {
          if idx == items.count - 1 { onAppearLast() }
        }
      }
    }
    .padding(.horizontal, 16)
  }
}
