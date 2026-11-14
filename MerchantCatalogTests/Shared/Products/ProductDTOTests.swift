import Foundation
import Testing
@testable import MerchantCatalog

/// DTO → domain mapping (D-37). Optional or unexpected values never fail a page: they map to `nil`
/// or are dropped.
struct ProductDTOTests {
    /// Decodes `ProductJSON.product` after applying `edit` to its JSON object.
    private static func product(_ edit: (inout [String: Any]) -> Void) throws -> Product {
        var object = try #require(
            try JSONSerialization.jsonObject(with: Data(ProductJSON.product.utf8)) as? [String: Any]
        )
        edit(&object)
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(ProductDTO.self, from: data).toDomain()
    }

    /// A list item has only the selected fields and maps to a `ProductSummary`, never to a
    /// `Product` that would look like a product without details (D-81).
    @Test func summaryDecodesTheSelectedFields() throws {
        let summary = try JSONDecoder().decode(ProductSummaryDTO.self, from: Data(ProductJSON.summary.utf8)).toDomain()

        #expect(summary == ProductSummary(
            id: 1,
            title: "Volume Mascara",
            price: Decimal(string: "9.99")!,
            thumbnailURL: URL(string: "https://cdn.dummyjson.com/products/1/thumbnail.webp"),
            rating: 4.94,
            category: "beauty",
            stock: 5
        ))
    }

    @Test func summaryMapsMissingAndBlankFieldsToNil() throws {
        let json = #"{"id": 3, "title": "Lamp", "price": 5, "category": "  ", "thumbnail": "https:foo"}"#

        let summary = try JSONDecoder().decode(ProductSummaryDTO.self, from: Data(json.utf8)).toDomain()

        #expect(summary.category == nil)
        #expect(summary.thumbnailURL == nil)
        #expect(summary.rating == nil)
        #expect(summary.stock == nil)
    }

    /// A full list item (as before `select`) still decodes as a summary of the same values.
    @Test func fullItemDecodesAsTheSameSummary() throws {
        let full = try JSONDecoder().decode(ProductSummaryDTO.self, from: Data(ProductJSON.product.utf8)).toDomain()
        let slim = try JSONDecoder().decode(ProductSummaryDTO.self, from: Data(ProductJSON.summary.utf8)).toDomain()

        #expect(full == slim)
    }

    @Test func decodesProductFixture() throws {
        let product = try JSONDecoder().decode(ProductDTO.self, from: Data(ProductJSON.product.utf8)).toDomain()

        #expect(product.id == 1)
        #expect(product.title == "Volume Mascara")
        #expect(product.price == Decimal(string: "9.99"))
        #expect(product.brand == "Acme")
        #expect(product.thumbnailURL == URL(string: "https://cdn.dummyjson.com/products/1/thumbnail.webp"))
        #expect(product.imageURLs.map(\.absoluteString) == [
            "https://cdn.dummyjson.com/products/1/1.webp",
            "https://cdn.dummyjson.com/products/1/2.webp",
            "https://cdn.dummyjson.com/products/1/3.webp",
        ])
    }

    @Test(arguments: [("", String?.none), ("  ", nil), ("Acme", "Acme")])
    func brandMapping(brand: String, expected: String?) throws {
        #expect(try Self.product { $0["brand"] = brand }.brand == expected)
    }

    @Test func missingBrandIsNil() throws {
        #expect(try Self.product { $0["brand"] = nil }.brand == nil)
    }

    /// D-84: the status follows `stock`, never the API's `availabilityStatus`, which disagrees with
    /// the stock for some demo products (Networking.md A16).
    @Test(arguments: [("In Stock", 7, StockStatus.lowStock), ("Low Stock", 40, .inStock), ("In Stock", 0, .outOfStock)])
    func statusComesFromStockNotAvailabilityStatus(apiStatus: String, stock: Int, expected: StockStatus) throws {
        let product = try Self.product {
            $0["availabilityStatus"] = apiStatus
            $0["stock"] = stock
        }

        #expect(product.stockStatus == expected)
    }

    @Test func missingStockHasNoStatus() throws {
        #expect(try Self.product { $0["stock"] = nil }.stockStatus == nil)
    }

    @Test func invalidImageURLsAreDropped() throws {
        let product = try Self.product {
            $0["images"] = ["https://cdn.dummyjson.com/products/1/1.webp", "", "not a url"]
            $0["thumbnail"] = ""
        }

        #expect(product.imageURLs.map(\.absoluteString) == ["https://cdn.dummyjson.com/products/1/1.webp"])
        #expect(product.thumbnailURL == nil)
    }

    /// Review finding 3: an `http(s)` scheme alone isn't enough; the URL needs a host.
    @Test(arguments: ["https:foo", "http:/x", "https://", "https:///products/1.webp", "ftp://cdn.dummyjson.com/1.webp"])
    func urlsWithoutAWebHostAreDropped(value: String) throws {
        let product = try Self.product {
            $0["images"] = [value, "https://cdn.dummyjson.com/products/1/1.webp"]
            $0["thumbnail"] = value
        }

        #expect(product.imageURLs.map(\.absoluteString) == ["https://cdn.dummyjson.com/products/1/1.webp"])
        #expect(product.thumbnailURL == nil)
    }

    @Test func missingImagesAndThumbnail() throws {
        let product = try Self.product {
            $0["images"] = nil
            $0["thumbnail"] = nil
        }

        #expect(product.imageURLs == [])
        #expect(product.thumbnailURL == nil)
    }

    // MARK: - Details fields (S4)

    @Test func decodesDetailsFields() throws {
        let product = try JSONDecoder().decode(ProductDTO.self, from: Data(ProductJSON.product.utf8)).toDomain()

        #expect(product.productDescription == "A lengthening mascara for everyday wear.")
        #expect(product.category == "beauty")
        #expect(product.tags == ["beauty", "mascara"])
        #expect(product.rating == 4.94)
        #expect(product.discountPercentage == 7.17)
        #expect(product.stock == 5)
        #expect(product.sku == "BEA-ACM-001")
        #expect(product.weight == 4)
        #expect(product.dimensions == ProductDimensions(width: 15.14, height: 13.08, depth: 22.99))
        #expect(product.warranty == "1 month warranty")
        #expect(product.shipping == "Ships in 1 month")
        #expect(product.returnPolicy == "No return policy")
        #expect(product.minimumOrderQuantity == 48)
        let date = try Date("2025-04-30T09:41:02.053Z", strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true))
        #expect(product.reviews == [
            ProductReview(rating: 3, comment: "Fine.", reviewerName: "Reviewer One", date: date),
        ])
    }

    @Test func missingDetailsFieldsAreEmpty() throws {
        let keys = [
            "description", "category", "tags", "rating", "discountPercentage", "stock", "sku", "weight",
            "dimensions", "warrantyInformation", "shippingInformation", "returnPolicy",
            "minimumOrderQuantity", "reviews",
        ]
        let product = try Self.product { object in
            for key in keys { object[key] = nil }
        }

        #expect(product.productDescription == nil)
        #expect(product.category == nil)
        #expect(product.tags == [])
        #expect(product.rating == nil)
        #expect(product.discountPercentage == nil)
        #expect(product.stock == nil)
        #expect(product.sku == nil)
        #expect(product.weight == nil)
        #expect(product.dimensions == nil)
        #expect(product.warranty == nil)
        #expect(product.shipping == nil)
        #expect(product.returnPolicy == nil)
        #expect(product.minimumOrderQuantity == nil)
        #expect(product.reviews == [])
    }

    @Test(arguments: ["description", "category", "sku", "warrantyInformation", "shippingInformation", "returnPolicy"])
    func blankDetailsStringsAreNil(key: String) throws {
        let product = try Self.product { $0[key] = "  " }

        let value: String? = switch key {
        case "description": product.productDescription
        case "category": product.category
        case "sku": product.sku
        case "warrantyInformation": product.warranty
        case "shippingInformation": product.shipping
        default: product.returnPolicy
        }
        #expect(value == nil)
    }

    @Test func blankTagsAreDropped() throws {
        #expect(try Self.product { $0["tags"] = ["beauty", " ", ""] }.tags == ["beauty"])
    }

    @Test func partialDimensionsAreNil() throws {
        let product = try Self.product { $0["dimensions"] = ["width": 1.5, "height": 2] }

        #expect(product.dimensions == nil)
    }

    /// Review Focus 4: the reviewer's email is never part of the domain model.
    @Test func reviewsMapWithoutEmail() throws {
        let product = try JSONDecoder().decode(ProductDTO.self, from: Data(ProductJSON.product.utf8)).toDomain()
        let review = try #require(product.reviews.first)

        let labels = Mirror(reflecting: review).children.compactMap(\.label)
        #expect(!labels.isEmpty)
        #expect(!labels.contains { $0.lowercased().contains("email") })
    }

    /// Review Focus 4: a malformed review never fails the page.
    @Test func malformedReviewFieldsAreNil() throws {
        let product = try Self.product {
            $0["reviews"] = [
                ["rating": 5, "comment": "Great.", "date": "yesterday", "reviewerName": "Reviewer Two"],
                [String: Any](),
            ]
        }

        #expect(product.reviews == [
            ProductReview(rating: 5, comment: "Great.", reviewerName: "Reviewer Two", date: nil),
        ])
    }

    @Test func pageMapping() throws {
        let page = try JSONDecoder().decode(ProductListResponseDTO.self, from: Data(ProductJSON.summaryPage.utf8)).toDomain()

        #expect(page.products.map(\.id) == [1, 2])
        #expect(page.total == 194)
        #expect(page.skip == 40)
        #expect(page.limit == 2)
    }
}
