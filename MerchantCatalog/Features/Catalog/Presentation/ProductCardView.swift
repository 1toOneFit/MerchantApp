import SwiftUI

/// A catalog card: square thumbnail, title (two lines, space always reserved so rows align), price
/// and, in the treatment arm, the rating (ProductSpecification § 4.1). The rating row is laid out in
/// both arms, hidden in control, so cards have the same height (D-21, D-71). On its own (the skeleton) VoiceOver reads it as one element;
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
            ProductCardRating(text: card.ratingText)
        }
        .accessibilityElement(children: .combine)
    }
}

/// "★ 4.9", or an invisible row of the same height when the card has no rating (control).
private struct ProductCardRating: View {
    let text: String?

    var body: some View {
        Label(text ?? "0.0", systemImage: "star.fill")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
            .opacity(text == nil ? 0 : 1)
            .accessibilityHidden(text == nil)
            .accessibilityLabel(text.map { "Rating \($0)" } ?? "")
    }
}
