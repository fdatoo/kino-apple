import KinoKit
import SwiftUI

/// Home tab: hero (continue-watching first, else recently-added) + two horizontal strips.
struct HomeView: View {
  @Environment(\.kinoClient) private var client
  @State private var vm = HomeViewModel()
  @State private var showAccountSheet = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          hero
          if !vm.continueWatching.isEmpty {
            continueWatchingStrip
          }
          if !vm.recentlyAdded.isEmpty {
            recentlyAddedStrip
          }
          if let error = vm.error {
            Text(error.localizedDescription)
              .font(.caption)
              .foregroundStyle(.secondary)
              .padding(.horizontal, 16)
          }
        }
        .padding(.bottom, 80)
      }
      .navigationTitle("Home")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          AvatarButton(initial: "F", badgeCount: 0) { showAccountSheet = true }
        }
      }
      .sheet(isPresented: $showAccountSheet) { AccountSheet() }
      .navigationDestination(for: UUID.self) { id in
        ItemDetailView(itemID: id)
      }
      .task {
        guard let client else { return }
        await vm.load(client)
      }
      .refreshable {
        guard let client else { return }
        await vm.load(client)
      }
    }
  }

  // MARK: - Hero

  @ViewBuilder
  private var hero: some View {
    if let item = vm.continueWatching.first {
      heroFromInProgress(item)
    } else if let item = vm.recentlyAdded.first {
      heroFromRecentlyAdded(item)
    } else if vm.isLoading {
      ProgressView()
        .frame(maxWidth: .infinity, minHeight: 240)
    }
  }

  private func heroFromInProgress(_ item: InProgressItem) -> some View {
    heroLayout(
      backdropURL: backdropURL(itemID: item.libraryItem.id),
      eyebrow: "Continue Watching",
      title: item.libraryItem.title ?? "Untitled",
      progress: progressFraction(position: item.positionSeconds, runtime: item.runtimeSeconds),
      ctaLabel: "Resume",
      targetID: UUID(uuidString: item.libraryItem.id)
    )
  }

  private func heroFromRecentlyAdded(_ item: MediaItem) -> some View {
    heroLayout(
      backdropURL: backdropURL(uuid: item.id),
      eyebrow: "Recently Added",
      title: item.title,
      progress: nil,
      ctaLabel: "Play",
      targetID: item.id
    )
  }

  private func heroLayout(
    backdropURL: URL?,
    eyebrow: String,
    title: String,
    progress: Double?,
    ctaLabel: String,
    targetID: UUID?
  ) -> some View {
    ZStack(alignment: .bottomLeading) {
      KinoAsyncImage(url: backdropURL, isInternal: true, cornerRadius: 0)
        .aspectRatio(contentMode: .fill)
        .frame(maxWidth: .infinity, maxHeight: 360)
        .clipped()
      LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
        .frame(maxWidth: .infinity, maxHeight: 360)
      VStack(alignment: .leading, spacing: 8) {
        Text(eyebrow.uppercased())
          .font(.caption2.weight(.bold))
          .foregroundStyle(.secondary)
          .tracking(1.2)
        Text(title)
          .font(.system(size: 28, weight: .heavy))
          .foregroundStyle(.white)
          .lineLimit(2)
        if let progress {
          ProgressView(value: progress)
            .tint(.white)
            .padding(.top, 4)
        }
        if let id = targetID {
          NavigationLink(value: id) {
            Label(ctaLabel, systemImage: "play.fill")
              .frame(maxWidth: 140)
              .padding(.vertical, 8)
              .background(.white, in: RoundedRectangle(cornerRadius: 8))
              .foregroundStyle(.black)
              .font(.callout.weight(.semibold))
          }
          .buttonStyle(.plain)
          .padding(.top, 8)
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 16)
    }
  }

  // MARK: - Strips

  private var continueWatchingStrip: some View {
    posterStrip(
      label: "Continue Watching",
      items: vm.continueWatching,
      id: \.libraryItem.id,
      posterURL: { posterURL(itemID: $0.libraryItem.id) },
      targetID: { UUID(uuidString: $0.libraryItem.id) }
    )
  }

  private var recentlyAddedStrip: some View {
    posterStrip(
      label: "Recently Added",
      items: vm.recentlyAdded,
      id: \.id,
      posterURL: { posterURL(uuid: $0.id) },
      targetID: { $0.id }
    )
  }

  @ViewBuilder
  private func posterStrip<Item, ID: Hashable>(
    label: String,
    items: [Item],
    id: KeyPath<Item, ID>,
    posterURL: @escaping (Item) -> URL?,
    targetID: @escaping (Item) -> UUID?
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(label)
        .font(.headline)
        .padding(.horizontal, 16)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(items, id: id) { item in
            if let uuid = targetID(item) {
              NavigationLink(value: uuid) {
                PosterCell(url: posterURL(item), title: nil)
                  .frame(width: 110)
              }
              .buttonStyle(.plain)
            }
          }
        }
        .padding(.horizontal, 16)
      }
    }
  }

  // MARK: - Helpers

  private func progressFraction(position: Int64, runtime: Int64?) -> Double? {
    guard let runtime, runtime > 0 else { return nil }
    return min(1.0, max(0.0, Double(position) / Double(runtime)))
  }

  private func backdropURL(itemID: String) -> URL? {
    guard let client else { return nil }
    return client.session.baseURL.appendingPathComponent(
      "api/v1/library/items/\(itemID)/images/backdrop"
    )
  }

  private func backdropURL(uuid: UUID) -> URL? {
    backdropURL(itemID: uuid.uuidString)
  }

  private func posterURL(itemID: String) -> URL? {
    guard let client else { return nil }
    return client.session.baseURL.appendingPathComponent(
      "api/v1/library/items/\(itemID)/images/poster"
    )
  }

  private func posterURL(uuid: UUID) -> URL? {
    posterURL(itemID: uuid.uuidString)
  }
}
