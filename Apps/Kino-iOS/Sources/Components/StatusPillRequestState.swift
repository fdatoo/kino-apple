import KinoKit
import SwiftUI

extension StatusPill.Status {
  /// Maps a `RequestState` to the appropriate `StatusPill.Status`.
  init(requestState: RequestState) {
    switch requestState {
    case .pending, .needsDisambiguation, .resolved:
      self = .resolving
    case .planning:
      self = .planning
    case .fulfilling, .ingesting:
      self = .fulfilling
    case .satisfied:
      self = .satisfied
    case .failed, .cancelled:
      self = .failed
    }
  }
}
