import Foundation
@testable import MerchantCatalog

/// A product whose fields derive from `id`: title "Product <id>", price `<id>.99`, a thumbnail URL.
func product(_ id: Int) -> Product {
    makeProduct(id: id, availability: .inStock)
}

/// A product with every field settable; unset details fields are absent (`nil` or empty).
func makeProduct(
    id: Int,
    title: String? = nil,
    price: Decimal? = nil,
    brand: String? = nil,
    availability: ProductAvailability? = nil,
    thumbnailURL: URL?? = nil,
    imageURLs: [URL] = [],
    productDescription: String? = nil,
    category: String? = nil,
    tags: [String] = [],
    rating: Double? = nil,
    discountPercentage: Double? = nil,
    stock: Int? = nil,
    sku: String? = nil,
    weight: Double? = nil,
    dimensions: ProductDimensions? = nil,
    warranty: String? = nil,
    shipping: String? = nil,
    returnPolicy: String? = nil,
    minimumOrderQuantity: Int? = nil,
    reviews: [ProductReview] = []
) -> Product {
    Product(
        id: id,
        title: title ?? "Product \(id)",
        price: price ?? Decimal(id) + Decimal(sign: .plus, exponent: -2, significand: 99),
        brand: brand,
        availability: availability,
        thumbnailURL: thumbnailURL ?? URL(string: "https://cdn.dummyjson.com/products/\(id)/thumbnail.webp"),
        imageURLs: imageURLs,
        productDescription: productDescription,
        category: category,
        tags: tags,
        rating: rating,
        discountPercentage: discountPercentage,
        stock: stock,
        sku: sku,
        weight: weight,
        dimensions: dimensions,
        warranty: warranty,
        shipping: shipping,
        returnPolicy: returnPolicy,
        minimumOrderQuantity: minimumOrderQuantity,
        reviews: reviews
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
