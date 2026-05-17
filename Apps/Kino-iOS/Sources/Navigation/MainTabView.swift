import SwiftUI

/// 4-tab capsule navigation: Home / Movies / Shows / Search.
struct MainTabView: View {
  @State private var selection: Tab = .home

  enum Tab: Hashable { case home, movies, shows, search }

  var body: some View {
    TabView(selection: $selection) {
      HomeView()
        .tabItem { Label("Home", systemImage: "house") }
        .tag(Tab.home)
      MoviesView()
        .tabItem { Label("Movies", systemImage: "film.stack") }
        .tag(Tab.movies)
      ShowsView()
        .tabItem { Label("Shows", systemImage: "tv") }
        .tag(Tab.shows)
      SearchView()
        .tabItem { Label("Search", systemImage: "magnifyingglass") }
        .tag(Tab.search)
    }
  }
}
