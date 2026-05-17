import KinoKit
import SwiftUI

/// Modal sheet presenting account navigation: requests, settings, and sign out.
struct AccountSheet: View {
  @Environment(\.kinoClient) private var client
  @Environment(AppState.self) private var appState
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        if let client {
          accountHeader(for: client)
        }
        Section("Your Stuff") {
          NavigationLink {
            RequestsView()
          } label: {
            Label("Your Requests", systemImage: "tray.full")
          }
        }
        Section("Configuration") {
          NavigationLink {
            SettingsView()
          } label: {
            Label("Settings", systemImage: "gear")
          }
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
      .navigationTitle("Account")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  @ViewBuilder
  private func accountHeader(for client: KinoClient) -> some View {
    Section {
      HStack(spacing: 12) {
        Image(systemName: "person.circle.fill")
          .font(.system(size: 44))
          .foregroundStyle(.tint)
        VStack(alignment: .leading, spacing: 2) {
          Text(client.session.deviceName)
            .font(.headline)
          HStack(spacing: 6) {
            Circle()
              .fill(.green)
              .frame(width: 8, height: 8)
            Text(client.session.baseURL.host ?? "—")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
      .padding(.vertical, 4)
    }
  }
}
