import SwiftUI

@main
struct KinoApp: App {
  @State private var appState = AppState()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(appState)
        .tint(.white)
    }
  }
}

/// Top-level view that switches between loading, unauth, auth, and error states.
private struct RootView: View {
  @Environment(AppState.self) private var appState

  var body: some View {
    switch appState.phase {
    case .loading:
      ProgressView().controlSize(.large)
    case .unauthenticated:
      PairingFlow()
    case .authenticated(let client):
      AdaptiveRoot()
        .environment(\.kinoClient, client)
    case .error(let error):
      VStack(spacing: 16) {
        Text("Couldn't load session").font(.headline)
        Text(error.localizedDescription).font(.caption).foregroundStyle(.secondary)
        Button("Retry") { Task { await appState.loadSession() } }
      }.padding()
    }
  }
}

/// Picks `MainTabView` on compact width, `MainSplitView` on regular (iPad).
private struct AdaptiveRoot: View {
  @Environment(\.horizontalSizeClass) private var hSize

  var body: some View {
    if hSize == .regular {
      MainSplitView()
    } else {
      MainTabView()
    }
  }
}
