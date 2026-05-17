import SwiftUI

/// Shows tab — filters the catalog to `media_kind = tv_episode`.
struct ShowsView: View {
  var body: some View { LibraryGridView(kind: .series) }
}
