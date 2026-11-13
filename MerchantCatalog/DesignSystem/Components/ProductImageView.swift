import SwiftUI

/// A product image that loads only while it is on screen and cancels an in-flight download when it
/// leaves (Networking.md § 4, D-78).
///
/// `.task(id: url)` starts the load when the view appears (or its URL changes) and SwiftUI cancels
/// it when the view disappears; the cancellation reaches the `URLSession` request through the
/// environment's `ImageLoading`. On disappear the model also releases a loaded image. The
/// placeholder is always present, so the layout never jumps. There is no cache: a reappearing image
/// downloads again (D-10).
struct ProductImageView: View {
    let url: URL?

    @Environment(\.imageLoader) private var loader
    @State private var model = ProductImageModel()

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.fill.tertiary)
            switch model.phase {
            case .loaded(let image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            case .failed:
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            case .empty:
                EmptyView()
            }
        }
        .task(id: url) { await model.load(url, using: loader) }
        .onDisappear { model.reset() }
        .accessibilityHidden(true)
    }
}
