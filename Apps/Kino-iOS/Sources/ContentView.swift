import KinoKit
import SwiftUI

struct ContentView: View {
  var body: some View {
    VStack(spacing: 12) {
      Text("Kino — iOS")
        .font(.title)
      Text("KinoKit version: \(KinoKit.version)")
        .font(.body.monospaced())
    }
    .padding()
  }
}
