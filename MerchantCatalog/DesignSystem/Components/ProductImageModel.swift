import UIKit

/// `ProductImageView`'s state (Networking.md § 4, D-78). The view calls `load(_:using:)` from
/// `.task(id: url)`, which SwiftUI starts when the view appears and cancels when it disappears or
/// the URL changes; cancelling cancels the request (`ImageLoading`). `reset()` on disappear releases
/// a loaded image, so an off-screen cell holds no decoded image (no in-memory cache, D-10).
@MainActor
@Observable
final class ProductImageModel {
    enum Phase: Equatable {
        /// The placeholder: nothing requested yet, loading, or cancelled.
        case empty
        case loaded(UIImage)
        /// The neutral failure icon; the next appearance tries again.
        case failed
    }

    private(set) var phase: Phase = .empty

    /// Shows the placeholder, then the image or the failure icon. A cancelled load leaves the
    /// placeholder, and a result that arrives after the cancellation is dropped.
    func load(_ url: URL?, using loader: any ImageLoading) async {
        phase = .empty
        guard let url else { return }
        do {
            let image = try await loader.image(from: url)
            guard !Task.isCancelled else { return }
            phase = .loaded(image)
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            phase = .failed
        }
    }

    func reset() {
        phase = .empty
    }
}
