import Testing
@testable import MerchantCatalog

/// Search and sort events and the S3 values of shared properties (Analytics.md § 2, § 3): names and
/// exact properties. No event carries the query text (D-18).
struct SearchAnalyticsEventTests {
    private typealias Case = (event: AnalyticsEvent, name: String, properties: [String: AnalyticsValue])

    private static let cases: [Case] = [
        (
            AnalyticsEvent.searchStarted(sort: .defaultOrder),
            "search_started",
            ["sort": .string("default_order")]
        ),
        (
            AnalyticsEvent.searchPerformed(trigger: .typing, queryLength: 5, wordCount: 1, sort: .priceAscending, resultCount: 20, totalCount: 23, durationMs: 140),
            "search_performed",
            ["trigger": .string("typing"), "query_length": .int(5), "word_count": .int(1), "sort": .string("price_asc"), "result_count": .int(20), "total_count": .int(23), "duration_ms": .int(140)]
        ),
        (
            AnalyticsEvent.searchPerformed(trigger: .sortChange, queryLength: 10, wordCount: 2, sort: .ratingDescending, resultCount: 0, totalCount: 0, durationMs: 90),
            "search_performed",
            ["trigger": .string("sort_change"), "query_length": .int(10), "word_count": .int(2), "sort": .string("rating_desc"), "result_count": .int(0), "total_count": .int(0), "duration_ms": .int(90)]
        ),
        (
            AnalyticsEvent.searchFailed(trigger: .retry, queryLength: 3, error: .offline),
            "search_failed",
            ["trigger": .string("retry"), "query_length": .int(3), "error_type": .string("offline")]
        ),
        (
            AnalyticsEvent.searchCleared(queryLength: 5, hadResults: false),
            "search_cleared",
            ["query_length": .int(5), "had_results": .bool(false)]
        ),
        (
            AnalyticsEvent.sortChanged(from: .defaultOrder, to: .ratingDescending, listContext: .search),
            "sort_changed",
            ["from_sort": .string("default_order"), "to_sort": .string("rating_desc"), "list_context": .string("search")]
        ),
        (
            AnalyticsEvent.catalogLoadCompleted(trigger: .sortChange, sort: .priceDescending, resultCount: 20, totalCount: 194, durationMs: 300),
            "catalog_load_completed",
            ["trigger": .string("sort_change"), "sort": .string("price_desc"), "result_count": .int(20), "total_count": .int(194), "duration_ms": .int(300)]
        ),
        (
            AnalyticsEvent.catalogPageRequested(listContext: .search, pageIndex: 2, sort: .priceAscending, isRetry: false),
            "catalog_page_requested",
            ["list_context": .string("search"), "page_index": .int(2), "sort": .string("price_asc"), "is_retry": .bool(false)]
        ),
        (
            AnalyticsEvent.retryRequested(failedSurface: .search, error: .timeout),
            "retry_requested",
            ["failed_surface": .string("search"), "error_type": .string("timeout")]
        ),
    ]

    @Test(arguments: cases)
    func namesAndProperties(event: AnalyticsEvent, name: String, properties: [String: AnalyticsValue]) {
        #expect(event.name.rawValue == name)
        #expect(event.properties == properties)
    }
}
