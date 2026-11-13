import SwiftUI

/// A catalog card: square thumbnail, title (two lines, space always reserved so rows align) and
/// price (ProductSpecification § 4.1). On its own (the skeleton) VoiceOver reads it as one element;
/// in the grid, `CatalogView` makes the card and its save button one element with the saved state
/// and a save action (`ProductCardAccessibility`).
struct ProductCardView: View {
    let card: ProductCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProductImageView(url: card.thumbnailURL)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 12))
            Text(card.title)
                .font(.subheadline)
                .lineLimit(2, reservesSpace: true)
            Text(card.price)
                .font(.headline)
        }
        .accessibilityElement(children: .combine)
    }
}
