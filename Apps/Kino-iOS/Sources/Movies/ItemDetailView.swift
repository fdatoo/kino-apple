import KinoKit
import SwiftUI

/// Item detail: backdrop, title, meta, Play CTA (player wiring lands in M3.7).
struct ItemDetailView: View {
  let itemID: UUID
  @Environment(\.kinoClient) private var client
  @State private var vm = ItemDetailViewModel()
  @State private var showPlayer = false

  var body: some View {
    ScrollView {
      if let item = vm.item {
        ZStack(alignment: .bottomLeading) {
          backdrop(for: item).frame(height: 380).clipped()
          LinearGradient(
            colors: [.clear, .black],
            startPoint: .top, endPoint: .bottom
          )
          .frame(height: 380)
          VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
              .font(.system(size: 34, weight: .heavy))
              .lineLimit(2)
            metaRow(for: item)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 16)
        }
        Button(action: { showPlayer = true }) {
          Label("Play", systemImage: "play.fill")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white)
        .foregroundStyle(.black)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .fullScreenCover(isPresented: $showPlayer) {
          if let item = vm.item {
            PlayerContainer(item: item)
              .preferredColorScheme(.dark)
          } else {
            VStack(spacing: 16) {
              Text("Item not loaded").foregroundStyle(.secondary)
              Button("Close") { showPlayer = false }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
          }
        }
      } else if let error = vm.error {
        VStack(spacing: 16) {
          Text("Couldn't load this title").font(.headline)
          Text(error.localizedDescription).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
      } else if vm.isLoading {
        ProgressView().padding(.top, 80)
      }
    }
    .ignoresSafeArea(edges: .top)
    .task { if let client { await vm.load(id: itemID, client: client) } }
  }

  @ViewBuilder
  private func backdrop(for item: MediaItem) -> some View {
    let url = client?.session.baseURL.appendingPathComponent(
      "api/v1/library/items/\(item.id.uuidString)/images/backdrop"
    )
    KinoAsyncImage(url: url, isInternal: true, cornerRadius: 0)
      .aspectRatio(contentMode: .fill)
  }

  @ViewBuilder
  private func metaRow(for item: MediaItem) -> some View {
    let parts: [String] = {
      var p: [String] = []
      if let r = item.runtimeSeconds { p.append("\(r / 60) min") }
      return p
    }()
    if !parts.isEmpty {
      Text(parts.joined(separator: " · "))
    }
  }
}
