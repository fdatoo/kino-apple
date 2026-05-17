import KinoKit
import SwiftUI

/// Thin-material banner that surfaces a `KinoError` with a dismiss affordance.
struct ErrorBanner: View {
  let error: KinoError
  let onDismiss: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill")
      Text(error.localizedDescription).lineLimit(2)
      Spacer()
      Button("Dismiss", action: onDismiss).buttonStyle(.plain)
        .font(.caption.weight(.semibold))
    }
    .padding(12)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 11))
    .overlay(RoundedRectangle(cornerRadius: 11).stroke(.white.opacity(0.1), lineWidth: 0.5))
    .padding(.horizontal, 16)
  }
}
