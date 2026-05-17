import KinoKit
import SwiftUI

/// Top-level coordinator for the full pairing flow.
///
/// Switches over `PairingViewModel.phase` to show the appropriate child view
/// and presents `ManualURLEntryView` as a sheet when the user requests manual entry.
struct PairingFlow: View {
  @Environment(AppState.self) private var appState
  @State private var vm = PairingViewModel()
  @State private var showManualEntry = false

  var body: some View {
    Group {
      switch vm.phase {
      case .discovering(let servers):
        ServerListView(
          servers: servers,
          onSelect: { server in await vm.select(server) },
          onManualEntry: { showManualEntry = true }
        )

      case .manualEntry:
        ServerListView(
          servers: [],
          onSelect: { server in await vm.select(server) },
          onManualEntry: { showManualEntry = true }
        )

      case .requestingCode(let server):
        VStack(spacing: 16) {
          ProgressView()
            .controlSize(.large)
          Text("Connecting to \(server.host)…")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

      case .awaitingApproval(let challenge, _):
        CodeView(challenge: challenge)

      case .failed(let error):
        VStack(spacing: 20) {
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 44))
            .foregroundStyle(.secondary)

          VStack(spacing: 8) {
            Text("Pairing failed")
              .font(.headline)
            Text(error.localizedDescription)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }

          Button("Try again") { vm.reset() }
            .buttonStyle(.borderedProminent)
        }
        .padding()
      }
    }
    .sheet(isPresented: $showManualEntry) {
      ManualURLEntryView(isPresented: $showManualEntry) { url in
        await vm.enterManualURL(url)
      }
    }
    .onAppear {
      vm.bind(appState)
      vm.startDiscovery()
    }
    .onDisappear {
      vm.stopDiscovery()
    }
  }
}
