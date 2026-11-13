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
}

/// How a session began: a cold launch, or a return to the foreground after the session timeout.
enum LaunchKind: String, Sendable {
    case cold
    case resume
}

/// Which list an event is about (`list_context`). S3 adds `search`.
enum ListContext: String, Sendable {
    case browse
}

/// Why a first page loaded (`trigger`). S3 adds `sort_change` and `typing`.
enum CatalogLoadTrigger: String, Sendable {
    case initial
    /// The full-screen Retry after a failed first page.
    case retry
    /// The empty state's Reload (D-38).
    case reload
}

/// How a pull-to-refresh ended (`result`, plus `error_type` on failure).
enum RefreshOutcome: Equatable, Sendable {
    case success
    case failure(AppError)
}

/// The surface whose Retry was tapped (`failed_surface`). S3/S4 add `search` and `details`.
enum FailedSurface: String, Sendable {
    case catalog
    case catalogPage = "catalog_page"
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
