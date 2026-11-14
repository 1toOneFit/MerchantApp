/// The loaded part of a paginated product list: items in server order without duplicate ids, and
/// where the next page starts (ProductSpecification § 4.1, Networking.md A1–A2).
///
/// Screen state, not a cache: it lives as long as the screen and is never persisted or shared.
struct CatalogListState: Equatable, Sendable {
    private(set) var items: [ProductSummary] = []
    /// Products in the whole result set, as the last page reported.
    private(set) var total = 0
    /// Offset of the next page: the raw count received so far, so dropped duplicates don't shift it.
    private(set) var nextSkip = 0
    private(set) var pagesLoaded = 0
    private var ids: Set<ProductSummary.ID> = []
    /// The last page was empty; asking again at the same offset would loop.
    private var lastPageWasEmpty = false

    var isEmpty: Bool { items.isEmpty }

    var canLoadMore: Bool {
        pagesLoaded > 0 && !lastPageWasEmpty && nextSkip < total
    }

    /// Starts over with the first page (initial load, retry, reload, refresh).
    mutating func replace(with page: ProductPage) {
        self = CatalogListState()
        append(page)
    }

    /// Appends `page`'s products whose ids aren't loaded yet; returns how many were new.
    @discardableResult
    mutating func append(_ page: ProductPage) -> Int {
        var added = 0
        for product in page.products {
            guard ids.insert(product.id).inserted else { continue }
            items.append(product)
            added += 1
        }
        total = page.total
        nextSkip = page.skip + page.products.count
        pagesLoaded += 1
        lastPageWasEmpty = page.products.isEmpty
        return added
    }
}
