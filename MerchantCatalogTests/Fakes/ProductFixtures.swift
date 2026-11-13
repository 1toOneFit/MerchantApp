import Foundation
@testable import MerchantCatalog

/// A product whose fields derive from `id`: title "Product <id>", price `<id>.99`, a thumbnail URL.
func product(_ id: Int) -> Product {
    Product(
        id: id,
        title: "Product \(id)",
        price: Decimal(id) + Decimal(sign: .plus, exponent: -2, significand: 99),
        brand: nil,
        availability: .inStock,
        thumbnailURL: URL(string: "https://cdn.dummyjson.com/products/\(id)/thumbnail.webp"),
        imageURLs: []
    )
}

/// A page holding the products `ids`, as the server would report it at `skip`.
func page(_ ids: ClosedRange<Int>, total: Int, skip: Int) -> ProductPage {
    ProductPage(products: ids.map(product), total: total, skip: skip, limit: ids.count)
}

/// An empty page (no matches, or an inconsistent server response).
func emptyPage(total: Int, skip: Int) -> ProductPage {
    ProductPage(products: [], total: total, skip: skip, limit: 0)
}
