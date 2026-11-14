#if DEBUG
import Foundation

/// The products UI tests see (D-88): four fixed products, one per stock status plus a second in
/// stock, with details and no images, so nothing touches the network. It plays the server: it
/// pages, sorts and searches (case-insensitive title match) the way the API does, so the catalog
/// runs its real code paths. Compiled in DEBUG only and registered only for `-ui-testing`
/// (`UITestLaunch`); production networking is untouched.
struct FixtureProductRepository: ProductRepository {
    static let products: [Product] = [
        fixture(id: 1, title: "Desk Lamp", price: 24.99, category: "home-decoration", rating: 4.6, stock: 42),
        fixture(id: 2, title: "Notebook Set", price: 9.99, category: "office-supplies", rating: 4.2, stock: 4),
        fixture(id: 3, title: "Travel Mug", price: 14.5, category: "kitchen-accessories", rating: 3.9, stock: 0),
        fixture(id: 4, title: "Wireless Mouse", price: 19.99, category: "accessories", rating: 4.4, stock: 15),
    ]

    func products(sort: ProductSort, skip: Int, limit: Int) async throws -> ProductPage {
        Self.page(of: Self.products, sort: sort, skip: skip, limit: limit)
    }

    func search(query: String, sort: ProductSort, skip: Int, limit: Int) async throws -> ProductPage {
        let matches = Self.products.filter { $0.title.localizedCaseInsensitiveContains(query) }
        return Self.page(of: matches, sort: sort, skip: skip, limit: limit)
    }

    func product(id: Product.ID) async throws -> Product {
        guard let product = Self.products.first(where: { $0.id == id }) else {
            throw AppError.notFound
        }
        return product
    }

    /// One page of `products` in `sort` order, as `/products` reports it (Networking.md A1).
    private static func page(of products: [Product], sort: ProductSort, skip: Int, limit: Int) -> ProductPage {
        let ordered = products.sorted { first, second in
            switch sort {
            case .defaultOrder: first.id < second.id
            case .priceAscending: (first.price, first.id) < (second.price, second.id)
            case .priceDescending: (first.price, second.id) > (second.price, first.id)
            case .ratingDescending: (first.rating ?? 0, second.id) > (second.rating ?? 0, first.id)
            }
        }
        let items = ordered.dropFirst(skip).prefix(limit).map(\.summary)
        return ProductPage(products: Array(items), total: ordered.count, skip: skip, limit: limit)
    }

    private static func fixture(id: Int, title: String, price: Decimal, category: String, rating: Double, stock: Int) -> Product {
        Product(
            id: id,
            title: title,
            price: price,
            brand: "Fixture Supply",
            thumbnailURL: nil,
            imageURLs: [],
            productDescription: "A fixed product for UI tests.",
            category: category,
            tags: [category],
            rating: rating,
            discountPercentage: nil,
            stock: stock,
            sku: "FIX-\(id)",
            weight: 1,
            dimensions: nil,
            warranty: nil,
            shipping: "Ships in 2 days",
            returnPolicy: "30 days return policy",
            minimumOrderQuantity: 1,
            reviews: []
        )
    }
}
#endif
