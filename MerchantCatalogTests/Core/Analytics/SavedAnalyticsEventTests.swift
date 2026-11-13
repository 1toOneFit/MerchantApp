import Foundation
import Testing
@testable import MerchantCatalog

/// Saved events and the S5 additions to details and selection events (Analytics.md § 3): names and
/// exact properties. Unknown values are omitted (D-63, D-68).
struct SavedAnalyticsEventTests {
    private static let cases: [(event: AnalyticsEvent, name: String, properties: [String: AnalyticsValue])] = [
        (
            AnalyticsEvent.productSaved(productID: 4, surface: .catalogCard, category: "beauty", price: Decimal(string: "9.99")!, position: 3, savedCountAfter: 2),
            "product_saved",
            [
                "product_id": .int(4),
                "surface": .string("catalog_card"),
                "category": .string("beauty"),
                "price": .double(9.99),
                "position": .int(3),
                "saved_count_after": .int(2),
            ]
        ),
        (
            AnalyticsEvent.productSaved(productID: 5, surface: .details, category: nil, price: Decimal(string: "1899.99")!, position: nil, savedCountAfter: 1),
            "product_saved",
            ["product_id": .int(5), "surface": .string("details"), "price": .double(1899.99), "saved_count_after": .int(1)]
        ),
        (
            AnalyticsEvent.productSaved(productID: 6, surface: .searchCard, category: nil, price: 2, position: 0, savedCountAfter: 3),
            "product_saved",
            ["product_id": .int(6), "surface": .string("search_card"), "price": .double(2), "position": .int(0), "saved_count_after": .int(3)]
        ),
        (
            AnalyticsEvent.productUnsaved(productID: 4, surface: .savedList, savedDurationS: 90, savedCountAfter: 0),
            "product_unsaved",
            ["product_id": .int(4), "surface": .string("saved_list"), "saved_duration_s": .int(90), "saved_count_after": .int(0)]
        ),
        (
            AnalyticsEvent.savedProductsViewed(savedCount: 3),
            "saved_products_viewed",
            ["saved_count": .int(3)]
        ),
        (
            AnalyticsEvent.savedProductRevisited(productID: 7, source: .saved, daysSinceSaved: 2),
            "saved_product_revisited",
            ["product_id": .int(7), "source": .string("saved"), "days_since_saved": .int(2)]
        ),
        (
            AnalyticsEvent.productDetailsLoadFailed(productID: 7, source: .saved, error: .offline, showingSnapshot: true),
            "product_details_load_failed",
            ["product_id": .int(7), "source": .string("saved"), "error_type": .string("offline"), "showing_snapshot": .bool(true)]
        ),
        (
            AnalyticsEvent.productDetailsLoadFailed(productID: 8, source: .saved, error: .notFound, showingSnapshot: true),
            "product_details_load_failed",
            ["product_id": .int(8), "source": .string("saved"), "error_type": .string("not_found"), "showing_snapshot": .bool(true)]
        ),
        (
            AnalyticsEvent.retryRequested(failedSurface: .details, error: .timeout),
            "retry_requested",
            ["failed_surface": .string("details"), "error_type": .string("timeout")]
        ),
        (
            AnalyticsEvent.productSelected(productID: 7, source: .saved, position: 1, sort: nil),
            "product_selected",
            ["product_id": .int(7), "source": .string("saved"), "position": .int(1)]
        ),
        (
            // D-63: from Saved, the snapshot lacks availability, discount and images.
            AnalyticsEvent.productDetailsViewed(productID: 7, source: .saved, category: "beauty", availability: nil, hasDiscount: nil, imageCount: nil, savedAt: date("2026-11-10T10:00:00Z"), contentOrigin: .snapshot),
            "product_details_viewed",
            [
                "product_id": .int(7),
                "source": .string("saved"),
                "category": .string("beauty"),
                "is_saved": .bool(true),
                "content_origin": .string("snapshot"),
            ]
        ),
    ]

    @Test(arguments: cases)
    func namesAndProperties(event: AnalyticsEvent, name: String, properties: [String: AnalyticsValue]) {
        #expect(event.name.rawValue == name)
        #expect(event.properties == properties)
    }

    @Test func savedChangeBecomesProductSaved() {
        let snapshot = SavedProduct(makeProduct(id: 4, category: "beauty"), savedAt: date("2026-11-13T10:00:00Z"))

        #expect(SavedProductsChange.saved(snapshot, countAfter: 2).event(surface: .catalogCard, position: 3)
            == .productSaved(productID: 4, surface: .catalogCard, category: "beauty", price: snapshot.price, position: 3, savedCountAfter: 2))
    }

    @Test func removedChangeBecomesProductUnsaved() {
        let snapshot = SavedProduct(product(4), savedAt: date("2026-11-13T10:00:00Z"))

        #expect(SavedProductsChange.removed(snapshot, savedDurationS: 90, countAfter: 0).event(surface: .details, position: nil)
            == .productUnsaved(productID: 4, surface: .details, savedDurationS: 90, savedCountAfter: 0))
    }
}
