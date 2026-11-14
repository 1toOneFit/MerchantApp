import Foundation

/// The list response: `{ products, total, skip, limit }` (Networking.md A1). Its items are
/// summaries: list and search pages select only the summary fields (D-81).
struct ProductListResponseDTO: Decodable, Sendable {
    let products: [ProductSummaryDTO]
    let total: Int
    let skip: Int
    let limit: Int

    func toDomain() -> ProductPage {
        ProductPage(products: products.map { $0.toDomain() }, total: total, skip: skip, limit: limit)
    }
}

/// A list item with the fields `select=title,price,thumbnail,rating,category` returns (`id` is
/// always included). Blank strings count as missing; a thumbnail without a web host is dropped.
struct ProductSummaryDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let price: Decimal
    let thumbnail: String?
    let rating: Double?
    let category: String?

    func toDomain() -> ProductSummary {
        ProductSummary(
            id: id,
            title: title,
            price: price,
            thumbnailURL: thumbnail.flatMap(ProductDTO.webURL),
            rating: rating,
            category: category.flatMap(ProductDTO.nonBlank)
        )
    }
}

/// A product as the API sends it from `/products/{id}`. Only the fields `Product` maps are decoded; everything beyond
/// `id`, `title` and `price` is optional so an unusual product never fails a whole page. Blank
/// strings count as missing.
struct ProductDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let price: Decimal
    let brand: String?
    let availabilityStatus: String?
    let thumbnail: String?
    let images: [String]?
    let description: String?
    let category: String?
    let tags: [String]?
    let rating: Double?
    let discountPercentage: Double?
    let stock: Int?
    let sku: String?
    let weight: Double?
    let dimensions: DimensionsDTO?
    let warrantyInformation: String?
    let shippingInformation: String?
    let returnPolicy: String?
    let minimumOrderQuantity: Int?
    let reviews: [ReviewDTO]?

    struct DimensionsDTO: Decodable, Sendable {
        let width: Double?
        let height: Double?
        let depth: Double?

        func toDomain() -> ProductDimensions? {
            guard let width, let height, let depth else { return nil }
            return ProductDimensions(width: width, height: height, depth: depth)
        }
    }

    /// `reviewerEmail` is deliberately not decoded: it is never displayed or logged
    /// (ProductSpecification § 4.3).
    struct ReviewDTO: Decodable, Sendable {
        let rating: Int?
        let comment: String?
        let reviewerName: String?
        let date: String?

        /// `nil` when the review has no rating, comment or reviewer name.
        func toDomain() -> ProductReview? {
            let comment = comment.flatMap(ProductDTO.nonBlank)
            let reviewerName = reviewerName.flatMap(ProductDTO.nonBlank)
            guard rating != nil || comment != nil || reviewerName != nil else { return nil }
            return ProductReview(
                rating: rating,
                comment: comment,
                reviewerName: reviewerName,
                date: date.flatMap { try? Date($0, strategy: ProductDTO.reviewDateFormat) }
            )
        }
    }

    /// `2025-04-30T09:41:02.053Z` (Networking.md A14).
    private static let reviewDateFormat = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    func toDomain() -> Product {
        Product(
            id: id,
            title: title,
            price: price,
            brand: brand.flatMap(Self.nonBlank),
            availability: availabilityStatus.flatMap(Self.availability),
            thumbnailURL: thumbnail.flatMap(Self.webURL),
            imageURLs: (images ?? []).compactMap(Self.webURL),
            productDescription: description.flatMap(Self.nonBlank),
            category: category.flatMap(Self.nonBlank),
            tags: (tags ?? []).compactMap(Self.nonBlank),
            rating: rating,
            discountPercentage: discountPercentage,
            stock: stock,
            sku: sku.flatMap(Self.nonBlank),
            weight: weight,
            dimensions: dimensions?.toDomain(),
            warranty: warrantyInformation.flatMap(Self.nonBlank),
            shipping: shippingInformation.flatMap(Self.nonBlank),
            returnPolicy: returnPolicy.flatMap(Self.nonBlank),
            minimumOrderQuantity: minimumOrderQuantity,
            reviews: (reviews ?? []).compactMap { $0.toDomain() }
        )
    }

    /// The string, or `nil` when it is only whitespace.
    static func nonBlank(_ string: String) -> String? {
        string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : string
    }

    private static func availability(_ status: String) -> ProductAvailability? {
        switch status {
        case "In Stock": .inStock
        case "Low Stock": .lowStock
        case "Out of Stock": .outOfStock
        default: nil
        }
    }

    /// An absolute `http(s)` URL with a host, or `nil` (`https:foo`, `https://` are rejected).
    static func webURL(_ string: String) -> URL? {
        guard
            let url = URL(string: string),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            let host = url.host(),
            !host.isEmpty
        else {
            return nil
        }
        return url
    }
}
