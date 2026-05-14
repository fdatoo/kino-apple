import SwiftUI

@main
struct KinoApp: App {
  var body: some Scene {
    Window("Kino", id: "kino-main") {
      ContentView()
    }
    .defaultSize(width: 480, height: 240)
  }
}
