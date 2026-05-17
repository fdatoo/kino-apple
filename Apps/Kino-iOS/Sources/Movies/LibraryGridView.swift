import KinoKit
import SwiftUI

/// Adaptive grid of poster cells filtered by media kind; pushes `ItemDetailView` on tap.
struct LibraryGridView: View {
  @Environment(\.kinoClient) private var client
  @State private var vm: LibraryGridViewModel

  init(kind: LibraryGridViewModel.Kind) {
    self._vm = State(initialValue: LibraryGridViewModel(kind: kind))
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 10) {
          ForEach(Array(vm.items.enumerated()), id: \.element.id) { idx, item in
            NavigationLink(value: item.id) {
              PosterCell(url: posterURL(for: item), title: nil)
            }
            .buttonStyle(.plain)
            .onAppear {
              if idx == vm.items.count - 1 {
                guard let client else { return }
                Task { await vm.loadMore(client) }
              }
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 80)
      }
      .navigationTitle(vm.kind == .movie ? "Movies" : "Shows")
      .task {
        guard let client else { return }
        await vm.loadInitial(client)
      }
      .navigationDestination(for: UUID.self) { id in
        ItemDetailView(itemID: id)
      }
    }
  }

  private func posterURL(for item: MediaItem) -> URL? {
    guard let client else { return nil }
    return client.session.baseURL.appendingPathComponent(
      "api/v1/library/items/\(item.id.uuidString)/images/poster"
    )
  }
}
