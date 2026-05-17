import SwiftUI

/// Movies tab — filters the catalog to `media_kind = movie`.
struct MoviesView: View {
  var body: some View { LibraryGridView(kind: .movie) }
}
