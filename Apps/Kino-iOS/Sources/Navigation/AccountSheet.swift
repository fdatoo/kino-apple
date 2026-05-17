import KinoKit
import SwiftUI

/// Account sheet shell — real rows and drill-ins land in M3.6.
struct AccountSheet: View {
  @Environment(\.kinoClient) private var client

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        if let client {
          VStack(alignment: .leading, spacing: 4) {
            Text(client.session.deviceName).font(.headline)
            Text("Server: \(client.session.baseURL.host ?? "—")")
              .font(.caption).foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading).padding()
        }
        Text("Account content lands in M3.6").foregroundStyle(.secondary)
        Spacer()
      }
    }
    .presentationDetents([.medium, .large])
  }
}
