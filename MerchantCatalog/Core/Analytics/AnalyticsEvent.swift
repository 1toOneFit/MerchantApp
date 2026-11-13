import Foundation

/// Event names from `docs/Analytics.md`. Only events whose status there is **Active** exist here;
/// `TaxonomyDocumentationTests` keeps the two equal.
enum AnalyticsEventName: String, CaseIterable, Sendable {
    case sessionStarted = "session_started"
    case appForegrounded = "app_foregrounded"
    case appBackgrounded = "app_backgrounded"
    case catalogViewed = "catalog_viewed"
    case catalogLoadCompleted = "catalog_load_completed"
    case catalogLoadFailed = "catalog_load_failed"
    case catalogRefreshed = "catalog_refreshed"
    case catalogPageRequested = "catalog_page_requested"
    case catalogPageLoaded = "catalog_page_loaded"
    case catalogPageFailed = "catalog_page_failed"
    case retryRequested = "retry_requested"
    case searchStarted = "search_started"
    case searchPerformed = "search_performed"
    case searchFailed = "search_failed"
    case searchCleared = "search_cleared"
    case sortChanged = "sort_changed"
    case productSelected = "product_selected"
    case productDetailsViewed = "product_details_viewed"
    case productGalleryInteracted = "product_gallery_interacted"
    case productDetailsLoadFailed = "product_details_load_failed"
    case productSaved = "product_saved"
    case productUnsaved = "product_unsaved"
    case savedProductsViewed = "saved_products_viewed"
    case savedProductRevisited = "saved_product_revisited"
    case experimentExposed = "experiment_exposed"
}

/// How a session began: a cold launch, or a return to the foreground after the session timeout.
enum LaunchKind: String, Sendable {
    case cold
    case resume
}

/// Which list an event is about (`list_context`): the catalog, or the results of a search.
enum ListContext: String, Sendable {
    case browse
    case search
}

/// Where a product was opened from (`source`).
enum ProductSource: String, Sendable {
    /// The browse grid.
    case catalog
    /// Search results.
    case search
    /// The Saved list.
    case saved
}

/// What the details screen showed first (`content_origin`): the product the list loaded
/// (Networking.md A7), or the saved snapshot (details opened from Saved, D-63).
enum ContentOrigin: String, Sendable {
    case list
    case snapshot
}

/// Where a save or removal happened (`surface`).
enum SaveSurface: String, Sendable {
    case catalogCard = "catalog_card"
    case searchCard = "search_card"
    case details
    case savedList = "saved_list"
}

/// Why the first page of the browse list loaded (`trigger`).
enum CatalogLoadTrigger: String, Sendable {
    case initial
    /// The full-screen Retry after a failed first page.
    case retry
    /// The empty state's Reload (D-38).
    case reload
    /// The user picked another sort (D-45).
    case sortChange = "sort_change"
}

/// Why the first page of search results loaded (`trigger` on search events, D-48).
enum SearchTrigger: String, Sendable {
    /// The query changed and the user stopped typing for the debounce interval.
    case typing
    /// The full-screen Retry after a failed search.
    case retry
    /// The user picked another sort while searching.
    case sortChange = "sort_change"
}

/// How a pull-to-refresh ended (`result`, plus `error_type` on failure).
enum RefreshOutcome: Equatable, Sendable {
    case success
    case failure(AppError)
}

/// The surface whose Retry was tapped (`failed_surface`).
enum FailedSurface: String, Sendable {
    case catalog
    /// A page ≥ 2 of the browse list or of search results (D-48).
    case catalogPage = "catalog_page"
    /// The first page of search results.
    case search
    /// The refresh of details opened from Saved.
    case details
}

/// A product-analytics event with its typed properties. Features create these and pass them to
/// `AnalyticsTracking.track(_:)`; `AnalyticsService` adds the envelope.
enum AnalyticsEvent: Equatable, Sendable {
    /// A new session began (Analytics.md § Lifecycle).
    case sessionStarted(isFirstSession: Bool, launchKind: LaunchKind)
    /// The app became active after being in the background.
    case appForegrounded(backgroundDurationS: Int)
    /// The user left the app.
    case appBackgrounded(foregroundDurationS: Int)
    /// The catalog became the visible tab (D-39).
    case catalogViewed(sort: ProductSort, listContext: ListContext)
    /// The first page of the browse list was received and shown.
    case catalogLoadCompleted(trigger: CatalogLoadTrigger, sort: ProductSort, resultCount: Int, totalCount: Int, durationMs: Int)
    /// The first page of the browse list could not be loaded.
    case catalogLoadFailed(trigger: CatalogLoadTrigger, sort: ProductSort, error: AppError, hasVisibleContent: Bool)
    /// A pull-to-refresh finished (D-41).
    case catalogRefreshed(listContext: ListContext, outcome: RefreshOutcome, durationMs: Int)
    /// A request for page ≥ 2 started.
    case catalogPageRequested(listContext: ListContext, pageIndex: Int, sort: ProductSort, isRetry: Bool)
    /// A page ≥ 2 was appended; `itemCount` counts new unique products.
    case catalogPageLoaded(listContext: ListContext, pageIndex: Int, itemCount: Int, hasMore: Bool, durationMs: Int)
    /// A page ≥ 2 could not be loaded.
    case catalogPageFailed(listContext: ListContext, pageIndex: Int, error: AppError)
    /// The user tapped a Retry control.
    case retryRequested(failedSurface: FailedSurface, error: AppError)
    /// The search query became non-empty (D-49).
    case searchStarted(sort: ProductSort)
    /// Results for the latest query were shown, zero included. Length and word count only, never the
    /// query text (D-18).
    case searchPerformed(trigger: SearchTrigger, queryLength: Int, wordCount: Int, sort: ProductSort, resultCount: Int, totalCount: Int, durationMs: Int)
    /// The first page of search results could not be loaded.
    case searchFailed(trigger: SearchTrigger, queryLength: Int, error: AppError)
    /// The search query became empty; `hadResults`: the search list on screen had products (D-49).
    case searchCleared(queryLength: Int, hadResults: Bool)
    /// The user picked a different sort for the list on screen.
    case sortChanged(from: ProductSort, to: ProductSort, listContext: ListContext)
    /// The user tapped a product card or Saved row; `position` is its 0-based index in the list on
    /// screen. `sort` is the list's order; Saved has none (D-68).
    case productSelected(productID: Int, source: ProductSource, position: Int, sort: ProductSort?)
    /// Details were first shown for a push (D-59). Unknown values are omitted; from Saved the
    /// snapshot has no availability, discount or images (D-63). `savedAt`: when the product was
    /// saved, `nil` if it isn't; sent only as `is_saved`, never as a date. `AnalyticsService` derives
    /// `saved_product_revisited` from it (D-64).
    case productDetailsViewed(productID: Int, source: ProductSource, category: String?, availability: ProductAvailability?, hasDiscount: Bool?, imageCount: Int?, savedAt: Date?, contentOrigin: ContentOrigin)
    /// The first swipe to another gallery image during a details visit (D-59).
    case productGalleryInteracted(productID: Int, imageCount: Int)
    /// `/products/{id}` failed for details opened from Saved.
    case productDetailsLoadFailed(productID: Int, source: ProductSource, error: AppError, showingSnapshot: Bool)
    /// The user saved a product. `price` is sent as a double; `category` and `position` (cards only)
    /// are omitted when absent.
    case productSaved(productID: Int, surface: SaveSurface, category: String?, price: Decimal, position: Int?, savedCountAfter: Int)
    /// The user removed a product from Saved.
    case productUnsaved(productID: Int, surface: SaveSurface, savedDurationS: Int, savedCountAfter: Int)
    /// The Saved tab became visible.
    case savedProductsViewed(savedCount: Int)
    /// Details of a product saved before the current session (derived by `AnalyticsService`, D-64).
    case savedProductRevisited(productID: Int, source: ProductSource, daysSinceSaved: Int)
    /// The first experiment card rendered in a session (`ExposureTracker`, Experiments.md).
    case experimentExposed(experiment: Experiment, assignment: ExperimentAssignment, surface: ExposureSurface)

    var name: AnalyticsEventName {
        switch self {
        case .sessionStarted: .sessionStarted
        case .appForegrounded: .appForegrounded
        case .appBackgrounded: .appBackgrounded
        case .catalogViewed: .catalogViewed
        case .catalogLoadCompleted: .catalogLoadCompleted
        case .catalogLoadFailed: .catalogLoadFailed
        case .catalogRefreshed: .catalogRefreshed
        case .catalogPageRequested: .catalogPageRequested
        case .catalogPageLoaded: .catalogPageLoaded
        case .catalogPageFailed: .catalogPageFailed
        case .retryRequested: .retryRequested
        case .searchStarted: .searchStarted
        case .searchPerformed: .searchPerformed
        case .searchFailed: .searchFailed
        case .searchCleared: .searchCleared
        case .sortChanged: .sortChanged
        case .productSelected: .productSelected
        case .productDetailsViewed: .productDetailsViewed
        case .productGalleryInteracted: .productGalleryInteracted
        case .productDetailsLoadFailed: .productDetailsLoadFailed
        case .productSaved: .productSaved
        case .productUnsaved: .productUnsaved
        case .savedProductsViewed: .savedProductsViewed
        case .savedProductRevisited: .savedProductRevisited
        case .experimentExposed: .experimentExposed
        }
    }

    var properties: [String: AnalyticsValue] {
        switch self {
        case .sessionStarted(let isFirstSession, let launchKind):
            ["is_first_session": .bool(isFirstSession), "launch_kind": .string(launchKind.rawValue)]
        case .appForegrounded(let backgroundDurationS):
            ["background_duration_s": .int(backgroundDurationS)]
        case .appBackgrounded(let foregroundDurationS):
            ["foreground_duration_s": .int(foregroundDurationS)]
        case .catalogViewed(let sort, let listContext):
            ["sort": .string(sort.analyticsValue), "list_context": .string(listContext.rawValue)]
        case .catalogLoadCompleted(let trigger, let sort, let resultCount, let totalCount, let durationMs):
            [
                "trigger": .string(trigger.rawValue),
                "sort": .string(sort.analyticsValue),
                "result_count": .int(resultCount),
                "total_count": .int(totalCount),
                "duration_ms": .int(durationMs),
            ]
        case .catalogLoadFailed(let trigger, let sort, let error, let hasVisibleContent):
            Self.errorProperties(error).merging([
                "trigger": .string(trigger.rawValue),
                "sort": .string(sort.analyticsValue),
                "has_visible_content": .bool(hasVisibleContent),
            ]) { $1 }
        case .catalogRefreshed(let listContext, let outcome, let durationMs):
            Self.refreshProperties(outcome).merging([
                "list_context": .string(listContext.rawValue),
                "duration_ms": .int(durationMs),
            ]) { $1 }
        case .catalogPageRequested(let listContext, let pageIndex, let sort, let isRetry):
            [
                "list_context": .string(listContext.rawValue),
                "page_index": .int(pageIndex),
                "sort": .string(sort.analyticsValue),
                "is_retry": .bool(isRetry),
            ]
        case .catalogPageLoaded(let listContext, let pageIndex, let itemCount, let hasMore, let durationMs):
            [
                "list_context": .string(listContext.rawValue),
                "page_index": .int(pageIndex),
                "item_count": .int(itemCount),
                "has_more": .bool(hasMore),
                "duration_ms": .int(durationMs),
            ]
        case .catalogPageFailed(let listContext, let pageIndex, let error):
            [
                "list_context": .string(listContext.rawValue),
                "page_index": .int(pageIndex),
                "error_type": .string(error.analyticsErrorType),
            ]
        case .retryRequested(let failedSurface, let error):
            ["failed_surface": .string(failedSurface.rawValue), "error_type": .string(error.analyticsErrorType)]
        case .searchStarted(let sort):
            ["sort": .string(sort.analyticsValue)]
        case .searchPerformed(let trigger, let queryLength, let wordCount, let sort, let resultCount, let totalCount, let durationMs):
            [
                "trigger": .string(trigger.rawValue),
                "query_length": .int(queryLength),
                "word_count": .int(wordCount),
                "sort": .string(sort.analyticsValue),
                "result_count": .int(resultCount),
                "total_count": .int(totalCount),
                "duration_ms": .int(durationMs),
            ]
        case .searchFailed(let trigger, let queryLength, let error):
            [
                "trigger": .string(trigger.rawValue),
                "query_length": .int(queryLength),
                "error_type": .string(error.analyticsErrorType),
            ]
        case .searchCleared(let queryLength, let hadResults):
            ["query_length": .int(queryLength), "had_results": .bool(hadResults)]
        case .sortChanged(let from, let to, let listContext):
            [
                "from_sort": .string(from.analyticsValue),
                "to_sort": .string(to.analyticsValue),
                "list_context": .string(listContext.rawValue),
            ]
        case .productSelected(let productID, let source, let position, let sort):
            [
                "product_id": .int(productID),
                "source": .string(source.rawValue),
                "position": .int(position),
                "sort": sort.map { .string($0.analyticsValue) },
            ].compactMapValues(\.self)
        case .productDetailsViewed(let productID, let source, let category, let availability, let hasDiscount, let imageCount, let savedAt, let contentOrigin):
            [
                "product_id": .int(productID),
                "source": .string(source.rawValue),
                "category": category.map(AnalyticsValue.string),
                "availability": availability.map { .string($0.analyticsValue) },
                "has_discount": hasDiscount.map(AnalyticsValue.bool),
                "image_count": imageCount.map(AnalyticsValue.int),
                "is_saved": .bool(savedAt != nil),
                "content_origin": .string(contentOrigin.rawValue),
            ].compactMapValues(\.self)
        case .productGalleryInteracted(let productID, let imageCount):
            ["product_id": .int(productID), "image_count": .int(imageCount)]
        case .productDetailsLoadFailed(let productID, let source, let error, let showingSnapshot):
            [
                "product_id": .int(productID),
                "source": .string(source.rawValue),
                "error_type": .string(error.analyticsErrorType),
                "showing_snapshot": .bool(showingSnapshot),
            ]
        case .productSaved(let productID, let surface, let category, let price, let position, let savedCountAfter):
            [
                "product_id": .int(productID),
                "surface": .string(surface.rawValue),
                "category": category.map(AnalyticsValue.string),
                "price": .double(price.analyticsValue),
                "position": position.map(AnalyticsValue.int),
                "saved_count_after": .int(savedCountAfter),
            ].compactMapValues(\.self)
        case .productUnsaved(let productID, let surface, let savedDurationS, let savedCountAfter):
            [
                "product_id": .int(productID),
                "surface": .string(surface.rawValue),
                "saved_duration_s": .int(savedDurationS),
                "saved_count_after": .int(savedCountAfter),
            ]
        case .savedProductsViewed(let savedCount):
            ["saved_count": .int(savedCount)]
        case .savedProductRevisited(let productID, let source, let daysSinceSaved):
            ["product_id": .int(productID), "source": .string(source.rawValue), "days_since_saved": .int(daysSinceSaved)]
        case .experimentExposed(let experiment, let assignment, let surface):
            [
                "experiment_id": .string(experiment.rawValue),
                "variant": .string(assignment.variant.rawValue),
                "assignment_source": .string(assignment.source.rawValue),
                "surface": .string(surface.rawValue),
            ]
        }
    }

    /// `error_type`, plus `http_status` when the failure was an HTTP status.
    private static func errorProperties(_ error: AppError) -> [String: AnalyticsValue] {
        var properties: [String: AnalyticsValue] = ["error_type": .string(error.analyticsErrorType)]
        if let status = error.httpStatus {
            properties["http_status"] = .int(status)
        }
        return properties
    }

    /// `result`, plus `error_type` on failure.
    private static func refreshProperties(_ outcome: RefreshOutcome) -> [String: AnalyticsValue] {
        switch outcome {
        case .success:
            ["result": .string("success")]
        case .failure(let error):
            ["result": .string("failure"), "error_type": .string(error.analyticsErrorType)]
        }
    }
}

extension ProductSort {
    /// The `sort` property value (Analytics.md § 2, shared property values).
    var analyticsValue: String {
        switch self {
        case .defaultOrder: "default_order"
        case .priceAscending: "price_asc"
        case .priceDescending: "price_desc"
        case .ratingDescending: "rating_desc"
        }
    }
}

extension Decimal {
    /// The nearest `Double` to the decimal as written: 1899.99 stays 1899.99, where
    /// `NSDecimalNumber.doubleValue` gives 1899.9900000000002.
    var analyticsValue: Double {
        Double(description) ?? NSDecimalNumber(decimal: self).doubleValue
    }
}

extension ProductAvailability {
    /// The `availability` property value (Analytics.md § 2, shared property values).
    var analyticsValue: String {
        switch self {
        case .inStock: "in_stock"
        case .lowStock: "low_stock"
        case .outOfStock: "out_of_stock"
        }
    }
}

extension AppError {
    /// The `error_type` property value (Analytics.md § 2, shared property values).
    var analyticsErrorType: String {
        switch self {
        case .offline: "offline"
        case .timeout: "timeout"
        case .notFound: "not_found"
        case .rateLimited: "rate_limited"
        case .server: "server"
        case .decoding: "decoding"
        case .unknown: "unknown"
        }
    }
}
