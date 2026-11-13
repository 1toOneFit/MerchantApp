import Foundation

/// DummyJSON product endpoints. S4/S5 add the single-product endpoint.
enum ProductsTarget: TargetType {
    /// One page of the catalog: `GET /products?limit=&skip=[&sortBy=&order=]`.
    case list(skip: Int, limit: Int, sort: ProductSort)
    /// One page of search results: `GET /products/search?q=&limit=&skip=[&sortBy=&order=]`. Search,
    /// sort and pagination work together on the server (Networking.md A3).
    case search(query: String, skip: Int, limit: Int, sort: ProductSort)

    var path: String {
        switch self {
        case .list: "/products"
        case .search: "/products/search"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .list(let skip, let limit, let sort):
            [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "skip", value: String(skip)),
            ] + Self.queryItems(for: sort)
        case .search(let query, let skip, let limit, let sort):
            [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "skip", value: String(skip)),
            ] + Self.queryItems(for: sort)
        }
    }

    /// The API ignores an unknown `sortBy` silently (A4), so every case maps to exact items.
    private static func queryItems(for sort: ProductSort) -> [URLQueryItem] {
        switch sort {
        case .defaultOrder:
            []
        case .priceAscending:
            [URLQueryItem(name: "sortBy", value: "price"), URLQueryItem(name: "order", value: "asc")]
        case .priceDescending:
            [URLQueryItem(name: "sortBy", value: "price"), URLQueryItem(name: "order", value: "desc")]
        case .ratingDescending:
            [URLQueryItem(name: "sortBy", value: "rating"), URLQueryItem(name: "order", value: "desc")]
        }
    }
}
