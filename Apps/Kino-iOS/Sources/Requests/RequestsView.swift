import KinoKit
import SwiftUI

/// Displays all media requests for the current session with pull-to-refresh.
struct RequestsView: View {
  @Environment(\.kinoClient) private var client
  @State private var vm = RequestsViewModel()

  var body: some View {
    List {
      if vm.isLoading && vm.requests.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity, alignment: .center)
          .listRowSeparator(.hidden)
      } else if vm.requests.isEmpty {
        Text("No requests yet.")
          .foregroundStyle(.secondary)
          .listRowSeparator(.hidden)
      } else {
        ForEach(vm.requests, id: \.id) { request in
          NavigationLink(value: request.id) {
            RequestRow(request: request)
          }
        }
      }
      if let error = vm.error {
        Text(error.localizedDescription)
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
    .navigationTitle("Your Requests")
    .navigationDestination(for: String.self) { id in
      RequestDetailView(requestID: id)
    }
    .refreshable {
      guard let client else { return }
      await vm.refresh(client)
    }
    .task {
      guard let client else { return }
      await vm.load(client)
    }
  }
}

/// A single row in the requests list.
private struct RequestRow: View {
  let request: RequestSummary

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "film.stack")
        .font(.title2)
        .foregroundStyle(.secondary)
        .frame(width: 44, height: 60)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
      VStack(alignment: .leading, spacing: 4) {
        Text(request.target.rawQuery)
          .font(.body.weight(.semibold))
          .lineLimit(2)
        Text(request.updatedAt.formatted(.relative(presentation: .named)))
          .font(.caption)
          .foregroundStyle(.secondary)
        StatusPill(status: StatusPill.Status(requestState: request.state))
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, 4)
  }
}
