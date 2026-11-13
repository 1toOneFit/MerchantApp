import Testing
@testable import MerchantCatalog

/// Catalog and reliability events (Analytics.md § 3): names and exact properties. Optional
/// properties (`http_status`, `error_type` on success) are absent, not empty.
struct CatalogAnalyticsEventTests {
    private typealias Case = (event: AnalyticsEvent, name: String, properties: [String: AnalyticsValue])

    private static let cases: [Case] = [
        (
            AnalyticsEvent.catalogViewed(sort: .defaultOrder, listContext: .browse),
            "catalog_viewed",
            ["sort": .string("default_order"), "list_context": .string("browse")]
        ),
        (
            AnalyticsEvent.catalogLoadCompleted(trigger: .initial, sort: .defaultOrder, resultCount: 20, totalCount: 194, durationMs: 250),
            "catalog_load_completed",
            ["trigger": .string("initial"), "sort": .string("default_order"), "result_count": .int(20), "total_count": .int(194), "duration_ms": .int(250)]
        ),
        (
            AnalyticsEvent.catalogLoadFailed(trigger: .retry, sort: .defaultOrder, error: .server(status: 503), hasVisibleContent: false),
            "catalog_load_failed",
            ["trigger": .string("retry"), "sort": .string("default_order"), "error_type": .string("server"), "http_status": .int(503), "has_visible_content": .bool(false)]
        ),
        (
            AnalyticsEvent.catalogLoadFailed(trigger: .reload, sort: .defaultOrder, error: .offline, hasVisibleContent: false),
            "catalog_load_failed",
            ["trigger": .string("reload"), "sort": .string("default_order"), "error_type": .string("offline"), "has_visible_content": .bool(false)]
        ),
        (
            AnalyticsEvent.catalogRefreshed(listContext: .browse, outcome: .success, durationMs: 120),
            "catalog_refreshed",
            ["list_context": .string("browse"), "result": .string("success"), "duration_ms": .int(120)]
        ),
        (
            AnalyticsEvent.catalogRefreshed(listContext: .browse, outcome: .failure(.timeout), durationMs: 15000),
            "catalog_refreshed",
            ["list_context": .string("browse"), "result": .string("failure"), "error_type": .string("timeout"), "duration_ms": .int(15000)]
        ),
        (
            AnalyticsEvent.catalogPageRequested(listContext: .browse, pageIndex: 2, sort: .defaultOrder, isRetry: false),
            "catalog_page_requested",
            ["list_context": .string("browse"), "page_index": .int(2), "sort": .string("default_order"), "is_retry": .bool(false)]
        ),
        (
            AnalyticsEvent.catalogPageLoaded(listContext: .browse, pageIndex: 3, itemCount: 18, hasMore: true, durationMs: 80),
            "catalog_page_loaded",
            ["list_context": .string("browse"), "page_index": .int(3), "item_count": .int(18), "has_more": .bool(true), "duration_ms": .int(80)]
        ),
        (
            AnalyticsEvent.catalogPageFailed(listContext: .browse, pageIndex: 2, error: .rateLimited),
            "catalog_page_failed",
            ["list_context": .string("browse"), "page_index": .int(2), "error_type": .string("rate_limited")]
        ),
        (
            AnalyticsEvent.retryRequested(failedSurface: .catalog, error: .offline),
            "retry_requested",
            ["failed_surface": .string("catalog"), "error_type": .string("offline")]
        ),
        (
            AnalyticsEvent.retryRequested(failedSurface: .catalogPage, error: .timeout),
            "retry_requested",
            ["failed_surface": .string("catalog_page"), "error_type": .string("timeout")]
        ),
    ]

    @Test(arguments: cases)
    func namesAndProperties(event: AnalyticsEvent, name: String, properties: [String: AnalyticsValue]) {
        #expect(event.name.rawValue == name)
        #expect(event.properties == properties)
    }

    @Test(arguments: [
        (ProductSort.defaultOrder, "default_order"),
        (.priceAscending, "price_asc"),
        (.priceDescending, "price_desc"),
        (.ratingDescending, "rating_desc"),
    ])
    func sortValues(sort: ProductSort, value: String) {
        #expect(sort.analyticsValue == value)
    }

    @Test(arguments: [
        (AppError.offline, "offline"),
        (.timeout, "timeout"),
        (.notFound, "not_found"),
        (.rateLimited, "rate_limited"),
        (.server(status: 500), "server"),
        (.decoding, "decoding"),
        (.unknown, "unknown"),
    ])
    func errorTypes(error: AppError, value: String) {
        #expect(error.analyticsErrorType == value)
    }
}
