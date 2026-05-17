import KinoKit
import SwiftUI

/// Shows the full detail for a single media request, including a status-event timeline and a cancel CTA.
struct RequestDetailView: View {
  let requestID: String

  @Environment(\.kinoClient) private var client
  @State private var vm = RequestDetailViewModel()

  var body: some View {
    Group {
      if vm.isLoading && vm.detail == nil {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let detail = vm.detail {
        content(detail)
      } else if let error = vm.error {
        VStack(spacing: 12) {
          Image(systemName: "exclamationmark.triangle")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
          Text(error.localizedDescription)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .navigationTitle("Request")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      guard let client else { return }
      await vm.load(id: requestID, client: client)
    }
  }

  @ViewBuilder
  private func content(_ detail: RequestDetail) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        header(detail)
        if !detail.statusEvents.isEmpty {
          timeline(detail.statusEvents)
        }
        if isCancellable(detail.request.state) {
          cancelButton(detail)
        }
        if let error = vm.error {
          Text(error.localizedDescription)
            .font(.caption)
            .foregroundStyle(.red)
            .padding(.horizontal)
        }
      }
      .padding()
    }
  }

  private func header(_ detail: RequestDetail) -> some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text(detail.request.target.rawQuery)
          .font(.title3.weight(.semibold))
          .fixedSize(horizontal: false, vertical: true)
        StatusPill(status: StatusPill.Status(requestState: detail.request.state))
      }
      Spacer(minLength: 0)
    }
  }

  private func timeline(_ events: [RequestStatusEvent]) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Timeline")
        .font(.headline)
        .padding(.bottom, 12)
      ForEach(Array(events.enumerated()), id: \.offset) { index, event in
        HStack(alignment: .top, spacing: 12) {
          VStack(spacing: 0) {
            Circle()
              .fill(stateColor(event.toState))
              .frame(width: 12, height: 12)
              .shadow(color: stateColor(event.toState).opacity(0.5), radius: 4)
            if index < events.count - 1 {
              Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 2)
                .frame(minHeight: 36)
            }
          }
          .frame(width: 12)
          VStack(alignment: .leading, spacing: 2) {
            HStack {
              Text(stateName(event.toState))
                .font(.callout.weight(.medium))
              Spacer(minLength: 0)
              Text(event.occurredAt.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if let message = event.message, !message.isEmpty {
              Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .padding(.bottom, index < events.count - 1 ? 20 : 0)
        }
      }
    }
  }

  private func cancelButton(_ detail: RequestDetail) -> some View {
    Button(role: .destructive) {
      guard let client else { return }
      Task { await vm.cancel(id: requestID, client: client) }
    } label: {
      if vm.isLoading {
        ProgressView()
          .frame(maxWidth: .infinity)
      } else {
        Text("Cancel Request")
          .frame(maxWidth: .infinity)
      }
    }
    .buttonStyle(.bordered)
    .tint(.red)
    .disabled(vm.isLoading)
  }

  /// Returns true when the request is in a non-terminal state where cancellation is meaningful.
  private func isCancellable(_ state: RequestState) -> Bool {
    switch state {
    case .pending, .needsDisambiguation, .resolved, .planning, .fulfilling, .ingesting:
      return true
    case .satisfied, .failed, .cancelled:
      return false
    }
  }

  private func stateColor(_ state: RequestState) -> Color {
    switch state {
    case .pending, .needsDisambiguation, .resolved:
      return Color(uiColor: .systemGray2)
    case .planning:
      return .blue
    case .fulfilling, .ingesting:
      return .orange
    case .satisfied:
      return .green
    case .failed, .cancelled:
      return .red
    }
  }

  private func stateName(_ state: RequestState) -> String {
    switch state {
    case .pending: "Pending"
    case .needsDisambiguation: "Needs Disambiguation"
    case .resolved: "Resolved"
    case .planning: "Planning"
    case .fulfilling: "Fulfilling"
    case .ingesting: "Ingesting"
    case .satisfied: "Satisfied"
    case .failed: "Failed"
    case .cancelled: "Cancelled"
    }
  }
}
