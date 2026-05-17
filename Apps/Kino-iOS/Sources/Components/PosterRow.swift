import SwiftUI

/// Horizontally scrolling row of posters with a section label.
struct PosterRow<Item: Identifiable>: View {
  let label: String
  let items: [Item]
  let poster: (Item) -> URL?
  let title: (Item) -> String?
  let onTap: (Item) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(label)
        .font(.headline)
        .padding(.horizontal, 16)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(items) { item in
            Button {
              onTap(item)
            } label: {
              PosterCell(url: poster(item), title: title(item))
                .frame(width: 110)
            }.buttonStyle(.plain)
          }
        }.padding(.horizontal, 16)
      }
    }
  }
}
