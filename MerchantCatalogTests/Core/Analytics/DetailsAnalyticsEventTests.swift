import Testing
@testable import MerchantCatalog

/// Product selection and details events (Analytics.md § 3 `product_selected`, Details): names and
/// exact properties. `is_saved` arrives in S5 (D-56); unknown category or availability is omitted
/// (D-59).
struct DetailsAnalyticsEventTests {
    private typealias Case = (event: AnalyticsEvent, name: String, properties: [String: AnalyticsValue])

    private static let cases: [Case] = [
        (
            AnalyticsEvent.productSelected(productID: 4, source: .search, position: 3, sort: .priceAscending),
            "product_selected",
            ["product_id": .int(4), "source": .string("search"), "position": .int(3), "sort": .string("price_asc")]
        ),
        (
            AnalyticsEvent.productSelected(productID: 1, source: .catalog, position: 0, sort: .defaultOrder),
            "product_selected",
            ["product_id": .int(1), "source": .string("catalog"), "position": .int(0), "sort": .string("default_order")]
        ),
        (
            AnalyticsEvent.productDetailsViewed(productID: 1, source: .catalog, category: "beauty", availability: .lowStock, hasDiscount: true, imageCount: 3, contentOrigin: .list),
            "product_details_viewed",
            [
                "product_id": .int(1),
                "source": .string("catalog"),
                "category": .string("beauty"),
                "availability": .string("low_stock"),
                "has_discount": .bool(true),
                "image_count": .int(3),
                "content_origin": .string("list"),
            ]
        ),
        (
            AnalyticsEvent.productDetailsViewed(productID: 2, source: .search, category: nil, availability: nil, hasDiscount: false, imageCount: 1, contentOrigin: .list),
            "product_details_viewed",
            [
                "product_id": .int(2),
                "source": .string("search"),
                "has_discount": .bool(false),
                "image_count": .int(1),
                "content_origin": .string("list"),
            ]
        ),
        (
            AnalyticsEvent.productDetailsViewed(productID: 3, source: .catalog, category: "groceries", availability: .inStock, hasDiscount: true, imageCount: 0, contentOrigin: .list),
            "product_details_viewed",
            [
                "product_id": .int(3),
                "source": .string("catalog"),
                "category": .string("groceries"),
                "availability": .string("in_stock"),
                "has_discount": .bool(true),
                "image_count": .int(0),
                "content_origin": .string("list"),
            ]
        ),
        (
            AnalyticsEvent.productDetailsViewed(productID: 4, source: .catalog, category: "vehicle", availability: .outOfStock, hasDiscount: false, imageCount: 6, contentOrigin: .list),
            "product_details_viewed",
            [
                "product_id": .int(4),
                "source": .string("catalog"),
                "category": .string("vehicle"),
                "availability": .string("out_of_stock"),
                "has_discount": .bool(false),
                "image_count": .int(6),
                "content_origin": .string("list"),
            ]
        ),
        (
            AnalyticsEvent.productGalleryInteracted(productID: 1, imageCount: 3),
            "product_gallery_interacted",
            ["product_id": .int(1), "image_count": .int(3)]
        ),
    ]

    @Test(arguments: cases)
    func namesAndProperties(event: AnalyticsEvent, name: String, properties: [String: AnalyticsValue]) {
        #expect(event.name.rawValue == name)
        #expect(event.properties == properties)
    }
}
