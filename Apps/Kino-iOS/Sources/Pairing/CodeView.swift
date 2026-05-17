import KinoKit
import SwiftUI

/// Displays the pairing code and a countdown timer while waiting for server approval.
struct CodeView: View {
  let challenge: PairingChallenge

  private func remaining(at date: Date) -> TimeInterval {
    max(0, challenge.expiresAt.timeIntervalSince(date))
  }

  private func formattedCountdown(at date: Date) -> String {
    let total = Int(remaining(at: date))
    let minutes = total / 60
    let seconds = total % 60
    return String(format: "%d:%02d", minutes, seconds)
  }

  private func isExpired(at date: Date) -> Bool { remaining(at: date) <= 0 }

  private func formatCode(_ raw: String) -> String {
    raw.count == 6 ? "\(raw.prefix(3))\u{2009}\(raw.suffix(3))" : raw
  }

  var body: some View {
    VStack(spacing: 32) {
      HStack {
        Text("Approve to pair")
          .font(.title.weight(.heavy))
        Spacer()
      }
      .padding(.horizontal, 22)
      .padding(.top, 8)

      VStack(spacing: 8) {
        Text(formatCode(challenge.code))
          .font(.system(size: 56, weight: .bold, design: .monospaced))
          .foregroundStyle(.primary)

        TimelineView(.periodic(from: .now, by: 1)) { context in
          Group {
            if isExpired(at: context.date) {
              Text("Code expired")
                .foregroundStyle(.red)
            } else {
              Text("Expires in \(formattedCountdown(at: context.date))")
                .foregroundStyle(.secondary)
            }
          }
          .font(.subheadline)
          .monospacedDigit()
        }
      }

      Divider()
        .padding(.horizontal, 40)

      VStack(alignment: .leading, spacing: 16) {
        instructionStep(
          number: 1,
          text: "Open the Kino server dashboard in a browser."
        )
        instructionStep(
          number: 2,
          text: "Go to Devices and select Pair new device."
        )
        instructionStep(
          number: 3,
          text: "Enter the code above to approve \(challenge.deviceName)."
        )
      }
      .padding(.horizontal, 32)

      Spacer()

      HStack(spacing: 8) {
        ProgressView()
          .controlSize(.small)
        Text("Waiting for approval…")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      .padding(.bottom, 32)
    }
  }

  private func instructionStep(number: Int, text: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Text("\(number)")
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
        .frame(width: 22, height: 22)
        .background(.tint, in: Circle())

      Text(text)
        .font(.subheadline)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
