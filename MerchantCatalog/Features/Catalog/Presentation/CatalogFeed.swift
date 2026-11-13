/// One list on the catalog screen and its loading state. `CatalogViewModel` owns the values and runs
/// the requests; this type only keeps the list, its cards and its statuses consistent.
///
/// `generation` stamps the list's latest page-1 load (initial, retry, reload, refresh). A result
/// stamped with another generation is stale and dropped (Architecture § 5).
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

    var sort: ProductSort
    private(set) var generation = 0
    private(set) var list = CatalogListState()
    /// One card per loaded product, in server order.
    private(set) var cards: [ProductCardModel] = []
    var firstPage: FirstPageStatus = .notLoaded
    var pageLoad: PageLoadStatus = .idle
    var refreshError: AppError?

    init(sort: ProductSort) {
        self.sort = sort
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
        case .loaded:
            list.isEmpty ? .empty : .content(footer: footer, refreshError: refreshError)
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
        cards = list.items.map { ProductCardModel(product: $0) }
        firstPage = .loaded
        pageLoad = .idle
    }

    /// A page ≥ 2 arrived; returns how many new products it added.
    mutating func appendPage(_ page: ProductPage) -> Int {
        let added = list.append(page)
        cards += list.items.suffix(added).map { ProductCardModel(product: $0) }
        pageLoad = .idle
        return added
    }
}
