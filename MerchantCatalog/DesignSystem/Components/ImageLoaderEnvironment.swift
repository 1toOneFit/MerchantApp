import SwiftUI

extension EnvironmentValues {
    /// The loader `ProductImageView` uses. `MerchantCatalogApp` sets the one `AppContext` registered
    /// as `any ImageLoading`; without it, images show the failure icon (D-78).
    @Entry var imageLoader: any ImageLoading = UnconfiguredImageLoader()
}

/// The environment's default: fails every load, so a missing injection is visible and logged
/// instead of silently using a hidden concrete loader.
struct UnconfiguredImageLoader: ImageLoading {
    func image(from url: URL) async throws -> UIImage {
        Log.network.error("No image loader in the environment")
        throw AppError.unknown
    }
}
