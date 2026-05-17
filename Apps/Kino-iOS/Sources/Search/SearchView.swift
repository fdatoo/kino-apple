import KinoKit
import SwiftUI

/// Search tab: debounced parallel library + discover queries with recent-query chips.
struct SearchView: View {
  @Environment(\.kinoClient) private var client
  @State private var vm = SearchViewModel()

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          searchField
          if vm.query.isEmpty {
            emptyState
          } else {
            results
          }
        }
        .padding(.bottom, 80)
      }
      .navigationTitle("Search")
      .navigationDestination(for: UUID.self) { id in
        ItemDetailView(itemID: id)
      }
      .task {
        if let client { vm.bind(client) }
      }
    }
  }

  private var searchField: some View {
    HStack {
      Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
      TextField(
        "Library and TMDB",
        text: $vm.query
      )
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .onSubmit { vm.submit() }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    .padding(.horizontal, 16)
  }

  @ViewBuilder private var emptyState: some View {
    if !vm.recents.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text("Recent").font(.caption.weight(.bold)).foregroundStyle(.secondary)
          .padding(.horizontal, 16)
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(vm.recents, id: \.self) { recent in
              Button {
                vm.query = recent
              } label: {
                Text(recent)
                  .font(.callout)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .background(.thinMaterial, in: Capsule())
              }
              .buttonStyle(.plain)
              .foregroundStyle(.primary)
            }
          }
          .padding(.horizontal, 16)
        }
      }
    }
  }

  @ViewBuilder private var results: some View {
    if !vm.libraryResults.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text("In Library")
          .font(.headline)
          .padding(.horizontal, 16)
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(vm.libraryResults, id: \.id) { item in
              NavigationLink(value: item.id) {
                PosterCell(url: posterURL(for: item), title: nil)
                  .frame(width: 110)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.horizontal, 16)
        }
      }
    }
    if !vm.discoverResults.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text("On TMDB")
          .font(.headline)
          .padding(.horizontal, 16)
        ForEach(vm.discoverResults, id: \.tmdbId) { candidate in
          discoverRow(for: candidate)
            .padding(.horizontal, 16)
        }
      }
    }
    if let error = vm.error {
      Text(error.localizedDescription)
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
    } else if vm.isSearching {
      ProgressView().padding(.top, 8)
    } else if vm.libraryResults.isEmpty && vm.discoverResults.isEmpty {
      Text("No matches yet.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
    }
  }

  private func discoverRow(for candidate: DiscoverCandidate) -> some View {
    HStack(alignment: .top, spacing: 12) {
      KinoAsyncImage(
        url: candidate.posterUrl.flatMap(URL.init(string:)),
        isInternal: false,
        cornerRadius: 6
      )
      .aspectRatio(2.0 / 3.0, contentMode: .fit)
      .frame(width: 60)
      VStack(alignment: .leading, spacing: 4) {
        Text(candidate.title).font(.body.weight(.semibold))
        if let year = candidate.year {
          Text(String(year)).font(.caption).foregroundStyle(.secondary)
        }
        if let overview = candidate.overview, !overview.isEmpty {
          Text(overview).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
      }
      Spacer()
      Button {
        guard let client else { return }
        Task { await vm.submitRequest(for: candidate, client: client) }
      } label: {
        Image(systemName: "plus.circle.fill")
          .font(.title2)
          .foregroundStyle(.tint)
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 6)
  }

  private func posterURL(for item: MediaItem) -> URL? {
    guard let client else { return nil }
    return client.session.baseURL.appendingPathComponent(
      "api/v1/library/items/\(item.id.uuidString)/images/poster"
    )
  }
}
