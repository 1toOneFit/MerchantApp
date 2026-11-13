import Foundation

/// The list response: `{ products, total, skip, limit }` (Networking.md A1).
struct ProductListResponseDTO: Decodable, Sendable {
    let products: [ProductDTO]
    let total: Int
    let skip: Int
    let limit: Int

    func toDomain() -> ProductPage {
        ProductPage(products: products.map { $0.toDomain() }, total: total, skip: skip, limit: limit)
    }
}

/// A product as the API sends it. Only the fields `Product` maps are decoded (D-37); everything
/// beyond `id`, `title` and `price` is optional so an unusual product never fails a whole page.
struct ProductDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let price: Decimal
    let brand: String?
    let availabilityStatus: String?
    let thumbnail: String?
    let images: [String]?

    func toDomain() -> Product {
        Product(
            id: id,
            title: title,
            price: price,
            brand: brand.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 },
            availability: availabilityStatus.flatMap(Self.availability),
            thumbnailURL: thumbnail.flatMap(Self.webURL),
            imageURLs: (images ?? []).compactMap(Self.webURL)
        )
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
    private static func webURL(_ string: String) -> URL? {
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
