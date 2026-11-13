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

    @Test func decodesProductFixture() throws {
        let product = try JSONDecoder().decode(ProductDTO.self, from: Data(ProductJSON.product.utf8)).toDomain()

        #expect(product.id == 1)
        #expect(product.title == "Volume Mascara")
        #expect(product.price == Decimal(string: "9.99"))
        #expect(product.brand == "Acme")
        #expect(product.availability == .lowStock)
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

    @Test(arguments: [
        ("In Stock", ProductAvailability?.some(.inStock)),
        ("Low Stock", .lowStock),
        ("Out of Stock", .outOfStock),
        ("Discontinued", nil),
    ])
    func availabilityMapping(status: String, expected: ProductAvailability?) throws {
        #expect(try Self.product { $0["availabilityStatus"] = status }.availability == expected)
    }

    @Test func missingAvailabilityIsNil() throws {
        #expect(try Self.product { $0["availabilityStatus"] = nil }.availability == nil)
    }

    @Test func invalidImageURLsAreDropped() throws {
        let product = try Self.product {
            $0["images"] = ["https://cdn.dummyjson.com/products/1/1.webp", "", "not a url"]
            $0["thumbnail"] = ""
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

    @Test func pageMapping() throws {
        let page = try JSONDecoder().decode(ProductListResponseDTO.self, from: Data(ProductJSON.page.utf8)).toDomain()

        #expect(page.products.map(\.id) == [1, 2])
        #expect(page.total == 194)
        #expect(page.skip == 40)
        #expect(page.limit == 2)
    }
}
