import KinoKit
import SwiftUI

struct ContentView: View {
  var body: some View {
    VStack(spacing: 24) {
      Text("Kino — tvOS")
        .font(.title)
      Button("KinoKit version: \(KinoKit.version)") {}
        .buttonStyle(.card)
    }
    .padding(64)
  }
}
