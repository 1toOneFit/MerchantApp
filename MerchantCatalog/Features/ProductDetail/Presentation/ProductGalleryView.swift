import SwiftUI

/// The details gallery: one page per image, swiped horizontally (ProductSpecification § 4.3 item 1).
/// Each page is a `ProductImageView`, which loads only while the page is on screen and shows a
/// placeholder while loading and an icon on failure (Networking.md § 4). The page indicator is
/// hidden for a single image.
struct ProductGalleryView: View {
    let gallery: ProductGalleryModel
    @Binding var selection: Int

    var body: some View {
        let count = gallery.imageURLs.count
        TabView(selection: $selection) {
            // The image list is fixed for the screen's lifetime, so its indices are stable ids.
            ForEach(gallery.imageURLs.indices, id: \.self) { index in
                ProductImageView(url: gallery.imageURLs[index])
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Product image \(index + 1) of \(count)")
                    .accessibilityAddTraits(.isImage)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: gallery.showsPageIndicator ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }
}
