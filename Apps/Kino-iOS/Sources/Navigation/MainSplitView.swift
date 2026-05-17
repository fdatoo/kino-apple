import KinoKit
import SwiftUI

/// iPad-only adaptive root: sidebar + detail panes via `NavigationSplitView`.
///
/// `HomeView` keeps its own toolbar avatar so that compact iPhones (driven by `MainTabView`)
/// retain access to the account sheet. On iPad in the split layout, the sidebar's avatar is
/// the primary entry point; HomeView's avatar still appears in the detail pane toolbar but is
/// redundant. The duplication is intentional — removing it would compromise iPhone UX.
struct MainSplitView: View {
  @State private var selection: MainTabView.Tab? = .home
  @State private var showAccountSheet = false

  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        Section("Browse") {
          Label("Home", systemImage: "house").tag(MainTabView.Tab.home)
          Label("Movies", systemImage: "film.stack").tag(MainTabView.Tab.movies)
          Label("Shows", systemImage: "tv").tag(MainTabView.Tab.shows)
          Label("Search", systemImage: "magnifyingglass").tag(MainTabView.Tab.search)
        }
      }
      .navigationTitle("Kino")
      .toolbar {
        ToolbarItem(placement: .bottomBar) {
          AvatarButton(initial: "F", badgeCount: 0) { showAccountSheet = true }
        }
      }
    } detail: {
      switch selection ?? .home {
      case .home: HomeView()
      case .movies: MoviesView()
      case .shows: ShowsView()
      case .search: SearchView()
      }
    }
    .sheet(isPresented: $showAccountSheet) { AccountSheet() }
  }
}
