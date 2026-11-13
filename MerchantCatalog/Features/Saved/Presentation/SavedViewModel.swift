import Observation

/// What the Saved tab shows.
enum SavedPhase: Equatable {
    /// The stored list hasn't been read yet (at launch).
    case loading
    case empty
    case content
}

/// The Saved tab's state and intents (ProductSpecification § 4.4). Rows come from the shared store,
/// so they work offline (AC-V3) and follow a save or removal anywhere (AC-V1). A row opens details
/// from its snapshot on the Saved tab's stack; the empty state's Browse catalog switches tabs through
/// `TabSelection` (D-61).
@MainActor
@Observable
final class SavedViewModel {
    @ObservationIgnored private let savedProducts: SavedProductsStore
    @ObservationIgnored private let analytics: any AnalyticsTracking
    /// The Saved tab's router.
    @ObservationIgnored private let router: Router
    @ObservationIgnored private let tabs: TabSelection

    init(savedProducts: SavedProductsStore, analytics: any AnalyticsTracking, router: Router, tabs: TabSelection) {
        self.savedProducts = savedProducts
        self.analytics = analytics
        self.router = router
        self.tabs = tabs
    }

    var phase: SavedPhase {
        if !savedProducts.isLoaded { return .loading }
        return savedProducts.items.isEmpty ? .empty : .content
    }

    /// Most recently saved first.
    var rows: [SavedRowModel] {
        savedProducts.items.map { SavedRowModel($0) }
    }

    /// The Saved tab became visible (D-39's rule).
    func savedBecameVisible() {
        analytics.track(.savedProductsViewed(savedCount: savedProducts.count))
    }

    /// A row was tapped: `product_selected` (no sort, D-68), then details from the snapshot.
    func rowSelected(id: Product.ID) {
        guard let position = savedProducts.items.firstIndex(where: { $0.id == id }) else { return }
        analytics.track(.productSelected(productID: id, source: .saved, position: position, sort: nil))
        router.showProductDetail(.saved(savedProducts.items[position]))
    }

    /// Swipe to remove (AC-V4).
    func removeSwiped(id: Product.ID) {
        guard let change = savedProducts.remove(id: id) else { return }
        analytics.track(change.event(surface: .savedList, position: nil))
    }

    /// The empty state's Browse catalog.
    func browseCatalogTapped() {
        tabs.select(.catalog)
    }
}
