import SwiftUI

/// A product image that loads only while it is on screen (Networking.md § 4, D-23).
///
/// Lazy grids may keep an off-screen cell's view alive, so `AsyncImage` alone wouldn't stop its
/// work when a cell scrolls away. Here `AsyncImage` exists only between `onAppear` and
/// `onDisappear`: appearing inserts it (the load starts), disappearing removes it (an in-flight load
/// is torn down, expected to cancel its request; verified manually, see Networking.md § 4). The
/// placeholder is always present, so the layout never jumps. There is no cache: a reappearing image
/// downloads again (D-10).
struct ProductImageView: View {
    let url: URL?

    @State private var isVisible = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.fill.tertiary)
            if isVisible, let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    case .empty:
                        Color.clear
                    @unknown default:
                        Color.clear
                    }
                }
                .id(url)
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .accessibilityHidden(true)
    }
}
