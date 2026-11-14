/// One list on the catalog screen and its loading state: the browse list, or the results of one
/// search query. `CatalogViewModel` owns the values and runs the requests; this type only keeps the
/// list, its cards and its statuses consistent.
///
/// `generation` stamps the list's latest page-1 load (initial, retry, reload, sort change, refresh).
/// A result stamped with another generation is stale and dropped (Architecture § 5). A new query
/// gets a new feed, so its stamp differs from every earlier query's.
struct CatalogFeed {
    enum FirstPageStatus: Equatable {
        case notLoaded
        case loading
        case loaded
        case failed(AppError)
    }

    enum PageLoadStatus: Equatable {
        case idle
        case loading
        case failed(AppError)
    }

    /// `nil` for the browse list.
    let query: SearchQuery?
    var sort: ProductSort
    private(set) var generation = 0
    /// The generation of the latest page-1 load, which refreshes don't change (`CatalogListContent`).
    private(set) var listID = 0
    private(set) var list = CatalogListState()
    /// One card per loaded product, in server order.
    private(set) var cards: [ProductCardModel] = []
    var firstPage: FirstPageStatus = .notLoaded
    var pageLoad: PageLoadStatus = .idle
    var refreshError: AppError?
    /// Decides whether the cards show the rating (`product_card_density_v1`, D-70).
    let cardVariant: ExperimentVariant

    init(query: SearchQuery?, sort: ProductSort, cardVariant: ExperimentVariant) {
        self.query = query
        self.sort = sort
        self.cardVariant = cardVariant
    }

    var context: ListContext {
        query == nil ? .browse : .search
    }

    /// What the list shows in `scope`: every card, or only those needing attention (D-85).
    func content(scope: CatalogScope) -> CatalogListContent {
        CatalogListContent(
            phase: phase,
            cards: scope == .all ? cards : cards.filter(\.needsAttention),
            listID: listID,
            scope: scope,
            attentionCount: attentionCount,
            coverage: coverage
        )
    }

    /// Loaded products that are low or out of stock.
    var attentionCount: Int {
        cards.count { $0.needsAttention }
    }

    /// What `attentionCount` is based on.
    var coverage: AttentionCoverage {
        AttentionCoverage(loaded: list.items.count, total: list.total, isComplete: !list.canLoadMore)
    }

    /// Products are on screen.
    var hasVisibleContent: Bool {
        firstPage == .loaded && !list.isEmpty
    }

    var phase: CatalogPhase {
        switch firstPage {
        case .notLoaded, .loading:
            .initialLoading
        case .failed(let error):
            .failed(error)
        case .loaded where list.isEmpty:
            query.map { .noResults(query: $0.text) } ?? .empty
        case .loaded:
            .content(footer: footer, refreshError: refreshError)
        }
    }

    private var footer: CatalogFooter {
        switch pageLoad {
        case .loading: .loading
        case .failed(let error): .failed(error)
        case .idle: list.canLoadMore ? .idle : .end
        }
    }

    /// A page-1 load starts: the skeleton shows until it finishes.
    mutating func beginFirstPage(generation: Int) {
        self.generation = generation
        listID = generation
        firstPage = .loading
        pageLoad = .idle
        refreshError = nil
    }

    /// A pull-to-refresh starts: content stays; a page load in flight is abandoned (D-41).
    mutating func beginRefresh(generation: Int) {
        self.generation = generation
        refreshError = nil
        if pageLoad == .loading {
            pageLoad = .idle
        }
    }

    /// Page 1 arrived: it replaces the list.
    mutating func applyFirstPage(_ page: ProductPage) {
        list.replace(with: page)
        cards = list.items.map { ProductCardModel(product: $0, variant: cardVariant) }
        firstPage = .loaded
        pageLoad = .idle
    }

    /// A page ≥ 2 arrived; returns how many new products it added.
    mutating func appendPage(_ page: ProductPage) -> Int {
        let added = list.append(page)
        cards += list.items.suffix(added).map { ProductCardModel(product: $0, variant: cardVariant) }
        pageLoad = .idle
        return added
    }
}
