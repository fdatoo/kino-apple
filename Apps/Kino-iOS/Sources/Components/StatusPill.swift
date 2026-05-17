import SwiftUI

/// Capsule badge indicating the lifecycle status of a request.
struct StatusPill: View {
  enum Status { case resolving, planning, fulfilling, satisfied, failed }
  let status: Status

  var body: some View {
    Text(label)
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 8).padding(.vertical, 3)
      .background(color.opacity(0.22), in: Capsule())
      .foregroundStyle(color)
  }

  private var label: String {
    switch status {
    case .resolving: "Resolving"
    case .planning: "Planning"
    case .fulfilling: "Fulfilling"
    case .satisfied: "Satisfied"
    case .failed: "Failed"
    }
  }

  private var color: Color {
    switch status {
    case .resolving: Color(uiColor: .systemGray2)
    case .planning: .blue
    case .fulfilling: .orange
    case .satisfied: .green
    case .failed: .red
    }
  }
}
