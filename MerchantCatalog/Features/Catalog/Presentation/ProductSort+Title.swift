extension ProductSort: Identifiable {
    /// Each case is its own stable identity, for the sort menu's `ForEach`.
    var id: Self { self }

    /// The option's title in the sort menu (ProductSpecification § 4.2).
    var title: String {
        switch self {
        case .defaultOrder: "Default"
        case .priceAscending: "Price: Low to High"
        case .priceDescending: "Price: High to Low"
        case .ratingDescending: "Rating: High to Low"
        }
    }

    /// The toolbar label that always shows the current sort; short enough to fit beside the title.
    var shortTitle: String {
        switch self {
        case .defaultOrder: "Default"
        case .priceAscending: "Lowest price"
        case .priceDescending: "Highest price"
        case .ratingDescending: "Top rated"
        }
    }
}
