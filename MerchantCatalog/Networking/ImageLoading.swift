import UIKit

/// What `ProductImageView` uses to download and decode a product image (Networking.md § 4, D-78).
/// Only `URLSessionImageLoader` touches `URLSession`; the app puts the registered loader into the
/// SwiftUI environment.
protocol ImageLoading: Sendable {
    /// Downloads and decodes the image at `url`.
    ///
    /// - Throws: `AppError` for failures (`.decoding` when the body isn't an image), or
    ///   `CancellationError` when the calling task is cancelled; cancelling also cancels the
    ///   underlying request.
    func image(from url: URL) async throws -> UIImage
}
