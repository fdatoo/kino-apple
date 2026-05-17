import KinoKit
import SwiftUI

/// Displays server, account, and app configuration for the current session.
struct SettingsView: View {
  @Environment(\.kinoClient) private var client
  @Environment(AppState.self) private var appState
  @Environment(\.dismiss) private var dismiss
  @State private var vm = SettingsViewModel()

  var body: some View {
    Form {
      serverSection
      accountSection
      aboutSection
    }
    .navigationTitle("Settings")
    .task {
      if let client { vm.bind(client) }
    }
  }

  private var serverSection: some View {
    Section("Server") {
      LabeledContent("Hostname", value: vm.hostname)
      LabeledContent("API Version", value: vm.apiVersion)
      LabeledContent("Instance ID", value: shortID(vm.instanceID))
      if vm.isAdmin {
        NavigationLink {
          Text("Paired devices admin lands in a later milestone.")
            .foregroundStyle(.secondary)
            .padding()
            .navigationTitle("Paired Devices")
        } label: {
          Label("Paired Devices", systemImage: "rectangle.connected.to.line.below")
        }
      }
    }
  }

  private var accountSection: some View {
    Section("Account") {
      LabeledContent("Device Name", value: vm.deviceName)
      Button(role: .destructive) {
        Task {
          await appState.signOut()
          dismiss()
        }
      } label: {
        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
      }
    }
  }

  private var aboutSection: some View {
    Section("About") {
      LabeledContent(
        "Version",
        value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
      )
      LabeledContent(
        "Build",
        value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
      )
      Text("Phase 4 spec")
        .foregroundStyle(.secondary)
    }
  }

  private func shortID(_ uuidString: String) -> String {
    String(uuidString.prefix(8)) + "…"
  }
}
