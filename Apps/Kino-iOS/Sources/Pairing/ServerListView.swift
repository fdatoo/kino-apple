import KinoKit
import SwiftUI

/// Displays a list of mDNS-discovered servers and a button to enter a URL manually.
struct ServerListView: View {
  let servers: [DiscoveredServer]
  let onSelect: (DiscoveredServer) async -> Void
  let onManualEntry: () -> Void

  var body: some View {
    NavigationStack {
      Group {
        if servers.isEmpty {
          emptyState
        } else {
          serverList
        }
      }
      .navigationTitle("Find your server")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .bottomBar) {
          Button("Find by URL") {
            onManualEntry()
          }
          .font(.body.weight(.medium))
          .frame(maxWidth: .infinity)
        }
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 20) {
      Spacer()
      ProgressView()
        .controlSize(.large)
      Text("Looking for Kino servers…")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  private var serverList: some View {
    List {
      Section {
        ForEach(servers, id: \.instanceID) { server in
          ServerRow(server: server, onSelect: onSelect)
        }
      } header: {
        Text("Available servers")
      }

      Section {
        Button {
          onManualEntry()
        } label: {
          Label("Enter server URL manually", systemImage: "link")
        }
      }
    }
    .listStyle(.insetGrouped)
  }
}

/// A single row representing one discovered server.
private struct ServerRow: View {
  let server: DiscoveredServer
  let onSelect: (DiscoveredServer) async -> Void

  var body: some View {
    Button {
      Task { await onSelect(server) }
    } label: {
      HStack(spacing: 12) {
        Image(systemName: "server.rack")
          .font(.title3)
          .foregroundStyle(.tint)
          .frame(width: 32)

        VStack(alignment: .leading, spacing: 2) {
          Text(server.name)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)

          if let version = server.txt["version"] {
            Text("v\(version)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
      .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
  }
}
