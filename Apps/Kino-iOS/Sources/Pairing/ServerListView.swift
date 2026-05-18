import KinoKit
import SwiftUI

/// Displays a list of mDNS-discovered servers and a button to enter a URL manually.
struct ServerListView: View {
  let servers: [DiscoveredServer]
  let onSelect: (DiscoveredServer) async -> Void
  let onManualEntry: () -> Void

  var body: some View {
    VStack(spacing: 24) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Find your server")
          .font(.title.weight(.heavy))
        Text("Looking for Kino servers on this network.")
          .foregroundStyle(.secondary)
          .font(.callout)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if servers.isEmpty {
        emptyStateCard
      } else {
        serverCard
      }

      Button(action: onManualEntry) {
        HStack {
          Image(systemName: "plus")
          Text("Enter URL manually")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        )
      }
      .buttonStyle(.plain)
      .foregroundStyle(.primary)

      Spacer()
    }
    .padding(22)
  }

  private var emptyStateCard: some View {
    VStack(spacing: 20) {
      ProgressView()
        .controlSize(.large)
      Text("Looking for Kino servers…")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(.white.opacity(0.05), lineWidth: 0.5)
    )
  }

  private var serverCard: some View {
    VStack(spacing: 0) {
      ForEach(servers, id: \.instanceID) { server in
        Button {
          Task { await onSelect(server) }
        } label: {
          serverRow(for: server)
        }
        .buttonStyle(.plain)

        if server.instanceID != servers.last?.instanceID {
          Divider()
            .background(.white.opacity(0.05))
        }
      }
    }
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(.white.opacity(0.05), lineWidth: 0.5)
    )
  }

  private func serverRow(for server: DiscoveredServer) -> some View {
    HStack(spacing: 12) {
      Circle()
        .fill(.green)
        .frame(width: 8, height: 8)

      VStack(alignment: .leading, spacing: 2) {
        Text(server.name)
          .font(.body.weight(.medium))
          .foregroundStyle(.primary)

        if let version = server.txt["version"] {
          Text("API v1 · v\(version)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .contentShape(Rectangle())
  }
}
