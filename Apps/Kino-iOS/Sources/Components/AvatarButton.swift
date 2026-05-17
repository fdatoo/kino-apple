import SwiftUI

/// Circular gradient avatar button showing a single initial and optional red badge count.
struct AvatarButton: View {
  let initial: String
  let badgeCount: Int
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack(alignment: .topTrailing) {
        Circle()
          .fill(
            LinearGradient(
              colors: [
                Color(red: 0.35, green: 0.54, blue: 1.0),
                Color(red: 0.7, green: 0.3, blue: 0.9),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .overlay(Text(initial).font(.headline).foregroundStyle(.white))
          .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 0.5))
          .frame(width: 32, height: 32)
        if badgeCount > 0 {
          Circle()
            .fill(.red)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(Color.black, lineWidth: 2))
            .offset(x: 2, y: -2)
        }
      }
    }.buttonStyle(.plain)
  }
}
