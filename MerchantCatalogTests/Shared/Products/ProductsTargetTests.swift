import Foundation
import Testing
@testable import MerchantCatalog

/// `ProductsTarget` builds the DummyJSON product endpoints (Networking.md § 2). Sort is a closed set
/// of query items because the API silently ignores an unknown `sortBy` (A4).
struct ProductsTargetTests {
    @Test(arguments: [
        (ProductSort.defaultOrder, [URLQueryItem]()),
        (.priceAscending, [URLQueryItem(name: "sortBy", value: "price"), URLQueryItem(name: "order", value: "asc")]),
        (.priceDescending, [URLQueryItem(name: "sortBy", value: "price"), URLQueryItem(name: "order", value: "desc")]),
        (.ratingDescending, [URLQueryItem(name: "sortBy", value: "rating"), URLQueryItem(name: "order", value: "desc")]),
    ])
    func listQueryItems(sort: ProductSort, sortItems: [URLQueryItem]) {
        let target = ProductsTarget.list(skip: 20, limit: 20, sort: sort)

        #expect(target.queryItems == [
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "skip", value: "20"),
        ] + sortItems)
    }

    @Test func listDefaults() {
        let target = ProductsTarget.list(skip: 0, limit: 20, sort: .defaultOrder)

        #expect(target.path == "/products")
        #expect(target.method == .get)
        #expect(target.baseURL == URL(string: "https://dummyjson.com"))
        #expect(target.timeout == 15)
        #expect(target.headers == [:])
    }
}
