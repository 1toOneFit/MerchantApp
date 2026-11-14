import Foundation

/// DummyJSON product endpoints.
enum ProductsTarget: TargetType {
    /// One page of the catalog: `GET /products?limit=&skip=&select=…[&sortBy=&order=]`.
    case list(skip: Int, limit: Int, sort: ProductSort)
    /// One page of search results: `GET /products/search?q=&limit=&skip=&select=…[&sortBy=&order=]`. Search,
    /// sort and pagination work together on the server (Networking.md A3).
    case search(query: String, skip: Int, limit: Int, sort: ProductSort)
    /// One product with all its details: `GET /products/{id}`; an unknown id is a 404 (Networking.md
    /// A6). Details fetch it whenever they open (D-81).
    case detail(id: Int)

    var path: String {
        switch self {
        case .list: "/products"
        case .search: "/products/search"
        case .detail(let id): "/products/\(id)"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .list(let skip, let limit, let sort):
            [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "skip", value: String(skip)),
                Self.summaryFields,
            ] + Self.queryItems(for: sort)
        case .search(let query, let skip, let limit, let sort):
            [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "skip", value: String(skip)),
                Self.summaryFields,
            ] + Self.queryItems(for: sort)
        case .detail:
            []
        }
    }

    /// List and search pages ask only for a summary's fields (D-81), the stock included (D-84); `id`
    /// is always included. The API ignores an unknown field name silently, so the value is pinned by
    /// a test.
    private static let summaryFields = URLQueryItem(name: "select", value: "title,price,thumbnail,rating,category,stock")

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
