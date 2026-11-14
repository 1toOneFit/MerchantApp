import Foundation
import Testing
@testable import MerchantCatalog

/// `ProductsTarget` builds the DummyJSON product endpoints (Networking.md § 2). Sort is a closed set
/// of query items because the API silently ignores an unknown `sortBy` (A4).
struct ProductsTargetTests {
    /// List and search pages ask only for what a list item shows (D-81), stock included for the
    /// card's status (D-84). The API silently ignores an unknown field name, so the exact value is
    /// pinned here.
    private static let select = URLQueryItem(name: "select", value: "title,price,thumbnail,rating,category,stock")

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
            Self.select,
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

    @Test(arguments: [
        (ProductSort.defaultOrder, [URLQueryItem]()),
        (.priceAscending, [URLQueryItem(name: "sortBy", value: "price"), URLQueryItem(name: "order", value: "asc")]),
        (.priceDescending, [URLQueryItem(name: "sortBy", value: "price"), URLQueryItem(name: "order", value: "desc")]),
        (.ratingDescending, [URLQueryItem(name: "sortBy", value: "rating"), URLQueryItem(name: "order", value: "desc")]),
    ])
    func searchQueryItems(sort: ProductSort, sortItems: [URLQueryItem]) {
        let target = ProductsTarget.search(query: "phone", skip: 20, limit: 20, sort: sort)

        #expect(target.queryItems == [
            URLQueryItem(name: "q", value: "phone"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "skip", value: "20"),
            Self.select,
        ] + sortItems)
    }

    @Test func searchPath() {
        let target = ProductsTarget.search(query: "phone", skip: 0, limit: 20, sort: .defaultOrder)

        #expect(target.path == "/products/search")
        #expect(target.method == .get)
    }

    /// `GET /products/{id}`: the full product, fetched whenever details open (D-81).
    @Test func detailPathHasNoQuery() {
        let target = ProductsTarget.detail(id: 7)

        #expect(target.path == "/products/7")
        #expect(target.queryItems == [])
        #expect(target.method == .get)
    }
}
