import SwiftUI

/// A catalog card: square thumbnail, title (two lines, space always reserved so rows align) and
/// price (ProductSpecification § 4.1). VoiceOver reads it as one element, "title, price"; S7 adds
/// the saved state and the save action.
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
