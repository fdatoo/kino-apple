import SwiftUI

/// 4-tab capsule navigation: Home / Movies / Shows / Search.
struct MainTabView: View {
  @State private var selection: Tab = .home
  @State private var showAccountSheet = false

  enum Tab: Hashable { case home, movies, shows, search }

  var body: some View {
    TabView(selection: $selection) {
      TabPlaceholder(title: "Home")
        .tabItem { Label("Home", systemImage: "house") }
        .tag(Tab.home)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            AvatarButton(initial: "F", badgeCount: 0) { showAccountSheet = true }
          }
        }
      MoviesView()
        .tabItem { Label("Movies", systemImage: "film.stack") }
        .tag(Tab.movies)
      ShowsView()
        .tabItem { Label("Shows", systemImage: "tv") }
        .tag(Tab.shows)
      TabPlaceholder(title: "Search")
        .tabItem { Label("Search", systemImage: "magnifyingglass") }
        .tag(Tab.search)
    }
    .sheet(isPresented: $showAccountSheet) {
      AccountSheet()
    }
  }
}

/// Placeholder content for a tab that lands in a later sub-issue.
private struct TabPlaceholder: View {
  let title: String

  var body: some View {
    NavigationStack {
      VStack {
        Spacer()
        Text(title).font(.largeTitle.weight(.heavy))
        Text("Lands in a later sub-issue").foregroundStyle(.secondary).font(.caption)
        Spacer()
      }.navigationTitle(title)
    }
  }
}
