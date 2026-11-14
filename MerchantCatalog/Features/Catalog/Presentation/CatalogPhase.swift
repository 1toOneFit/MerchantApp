/// What the catalog screen shows (ProductSpecification § 4.1 states; Architecture § 8).
enum CatalogPhase: Equatable {
    /// No content yet, first page in flight: the skeleton grid.
    case initialLoading
    /// At least one product. Pull-to-refresh uses the system refresh control; a refresh failure
    /// shows `refreshError` as a banner over the content.
    case content(footer: CatalogFooter, refreshError: AppError?)
    /// A successful first page of the browse list with no products: message and Reload.
    case empty
    /// A search with no matches: `No products match "<query>"` and Clear search (AC-S5).
    case noResults(query: String)
    /// The first page failed: full-screen, reason-specific message and Retry.
    case failed(AppError)
}

/// The row under the grid.
enum CatalogFooter: Equatable {
    /// More pages exist; the next loads when the user scrolls near the end.
    case idle
    /// Page ≥ 2 in flight: spinner.
    case loading
    /// Page ≥ 2 failed: message and Retry; content stays.
    case failed(AppError)
    /// Everything is loaded: "You've reached the end".
    case end
}

/// What one list shows: the browse list, or the results of the current search. The view keeps the
/// browse list on screen, hidden, while search results are shown (D-47).
struct CatalogListContent: Equatable {
    let phase: CatalogPhase
    /// Every loaded product's card, in server order.
    let allCards: [ProductCardModel]
    /// The cards of the products needing attention, in server order (D-85).
    let attentionCards: [ProductCardModel]
    /// Changes whenever page 1 loads anew (initial load, Retry, Reload, sort change, new query), never
    /// on load-more or pull-to-refresh. The view gives each list its own grid, so a new list starts
    /// at the top (ProductSpecification § 4.2).
    let listID: Int
    let scope: CatalogScope
    /// Loaded products of the list that are low or out of stock, in either scope.
    let attentionCount: Int
    /// What `attentionCount` is based on.
    let coverage: AttentionCoverage

    /// The cards of the selected scope: what is on screen.
    var cards: [ProductCardModel] { cards(in: scope) }

    func cards(in scope: CatalogScope) -> [ProductCardModel] {
        scope == .all ? allCards : attentionCards
    }
}
