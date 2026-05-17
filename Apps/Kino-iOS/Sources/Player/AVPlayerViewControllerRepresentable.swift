import AVKit
import SwiftUI

/// SwiftUI wrapper around `AVPlayerViewController` with PiP enabled.
struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
  let player: AVPlayer

  func makeUIViewController(context: Context) -> AVPlayerViewController {
    let vc = AVPlayerViewController()
    vc.player = player
    vc.allowsPictureInPicturePlayback = true
    vc.entersFullScreenWhenPlaybackBegins = true
    return vc
  }

  func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
    if vc.player !== player {
      vc.player = player
    }
  }
}
