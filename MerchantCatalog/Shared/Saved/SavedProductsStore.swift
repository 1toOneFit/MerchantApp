import Foundation
import Observation

/// What a save or a removal changed, for the caller's analytics event.
enum SavedProductsChange: Equatable, Sendable {
    case saved(SavedProduct, countAfter: Int)
    /// `savedDurationS`: whole seconds since the product was saved; 0 if the clock moved back (D-68).
    case removed(SavedProduct, savedDurationS: Int, countAfter: Int)

    /// `product_saved` or `product_unsaved` for a change made on `surface`; `position` only for
    /// cards (Analytics.md § 3 Saved).
    func event(surface: SaveSurface, position: Int?) -> AnalyticsEvent {
        switch self {
        case .saved(let item, let countAfter):
            .productSaved(productID: item.id, surface: surface, category: item.summary.category, price: item.summary.price, position: position, savedCountAfter: countAfter)
        case .removed(let item, let savedDurationS, let countAfter):
            .productUnsaved(productID: item.id, surface: surface, savedDurationS: savedDurationS, savedCountAfter: countAfter)
        }
    }
}

/// The saved products every screen observes (Architecture § 9): the card icons, the details
/// toolbar, the Saved list and the tab badge read this one instance, so a change shows everywhere
/// at once without notifications (AC-V1).
///
/// - `load()` reads the repository once at launch. Changes made before it finishes are kept: the
///   stored list is merged under them, then written once (D-66).
/// - Every later change writes the whole list. Writes are chained, each waiting for the previous
///   one, so the file always ends with the latest list.
/// - `saved_products_count` is set after the load and after every change (Analytics.md § 2).
@MainActor
@Observable
final class SavedProductsStore {
    /// Most recently saved first.
    private(set) var items: [SavedProduct] = []
    /// The stored list has been read.
    private(set) var isLoaded = false
    var count: Int { items.count }
    /// The latest write, chained after the previous ones; tests await it.
    @ObservationIgnored private(set) var writeTask: Task<Void, Never>?

    @ObservationIgnored private var hasStartedLoading = false
    /// Products saved or removed before the stored list was known.
    @ObservationIgnored private var changedBeforeLoad: Set<Product.ID> = []
    @ObservationIgnored private let repository: any SavedProductsRepository
    @ObservationIgnored private let analytics: any AnalyticsTracking
    @ObservationIgnored private let now: () -> Date

    init(repository: any SavedProductsRepository, analytics: any AnalyticsTracking, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.analytics = analytics
        self.now = now
    }

    /// Reads the stored list; only the first call does anything.
    func load() async {
        guard !hasStartedLoading else { return }
        hasStartedLoading = true
        let stored = await repository.load()
        let kept = stored.filter { !changedBeforeLoad.contains($0.id) }
        items = (items + kept).sorted { $0.savedAt > $1.savedAt }
        isLoaded = true
        if !changedBeforeLoad.isEmpty {
            changedBeforeLoad = []
            persist()
        }
        analytics.setUserProperty(.savedProductsCount(count))
    }

    func isSaved(_ id: Product.ID) -> Bool {
        items.contains { $0.id == id }
    }

    func item(id: Product.ID) -> SavedProduct? {
        items.first { $0.id == id }
    }

    /// Saves a snapshot of `product`, now; `nil` if it is already saved.
    @discardableResult
    func save(_ product: ProductSummary) -> SavedProductsChange? {
        guard !isSaved(product.id) else { return nil }
        let snapshot = SavedProduct(summary: product, savedAt: now())
        items.insert(snapshot, at: 0)
        didChange(product.id)
        return .saved(snapshot, countAfter: count)
    }

    /// Removes the product; `nil` if it isn't saved.
    @discardableResult
    func remove(id: Product.ID) -> SavedProductsChange? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = items.remove(at: index)
        didChange(id)
        let seconds = now().timeIntervalSince(removed.savedAt)
        return .removed(removed, savedDurationS: max(0, Int(seconds)), countAfter: count)
    }

    private func didChange(_ id: Product.ID) {
        guard isLoaded else {
            changedBeforeLoad.insert(id)
            return
        }
        persist()
        analytics.setUserProperty(.savedProductsCount(count))
    }

    /// Writes the current list after the previous write. An unstructured task because a tap (a
    /// synchronous callback) starts it; the store keeps the handle so writes stay ordered.
    private func persist() {
        let items = items
        let repository = repository
        let previous = writeTask
        writeTask = Task {
            await previous?.value
            await repository.save(items)
        }
    }
}
