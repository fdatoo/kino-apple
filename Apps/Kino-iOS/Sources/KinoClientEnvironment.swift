import KinoKit
import SwiftUI

private struct KinoClientKey: EnvironmentKey {
  static let defaultValue: KinoClient? = nil
}

/// SwiftUI environment key providing the active `KinoClient` to the view hierarchy.
extension EnvironmentValues {
  var kinoClient: KinoClient? {
    get { self[KinoClientKey.self] }
    set { self[KinoClientKey.self] = newValue }
  }
}
