import Foundation

/// Product JSON shaped like a DummyJSON list item (Networking.md A7: the full object, including
/// fields S2 ignores), with neutral demo values.
enum ProductJSON {
    static let product = """
    {
      "id": 1,
      "title": "Volume Mascara",
      "description": "A lengthening mascara for everyday wear.",
      "category": "beauty",
      "price": 9.99,
      "discountPercentage": 7.17,
      "rating": 4.94,
      "stock": 5,
      "tags": ["beauty", "mascara"],
      "brand": "Acme",
      "sku": "BEA-ACM-001",
      "weight": 4,
      "dimensions": { "width": 15.14, "height": 13.08, "depth": 22.99 },
      "warrantyInformation": "1 month warranty",
      "shippingInformation": "Ships in 1 month",
      "availabilityStatus": "Low Stock",
      "reviews": [
        { "rating": 3, "comment": "Fine.", "date": "2025-04-30T09:41:02.053Z", "reviewerName": "Reviewer One", "reviewerEmail": "reviewer.one@example.com" }
      ],
      "returnPolicy": "No return policy",
      "minimumOrderQuantity": 48,
      "meta": { "createdAt": "2025-04-30T09:41:02.053Z", "updatedAt": "2025-04-30T09:41:02.053Z", "barcode": "5784719087687", "qrCode": "https://cdn.dummyjson.com/public/qr-code.png" },
      "images": [
        "https://cdn.dummyjson.com/products/1/1.webp",
        "https://cdn.dummyjson.com/products/1/2.webp",
        "https://cdn.dummyjson.com/products/1/3.webp"
      ],
      "thumbnail": "https://cdn.dummyjson.com/products/1/thumbnail.webp"
    }
    """

    /// A list item as the API sends it with `select=title,price,thumbnail,rating,category` (D-81).
    static let summary = """
    {
      "id": 1,
      "title": "Volume Mascara",
      "price": 9.99,
      "rating": 4.94,
      "category": "beauty",
      "thumbnail": "https://cdn.dummyjson.com/products/1/thumbnail.webp"
    }
    """

    /// A list response with two copies of `summary` (ids 1 and 2).
    static let summaryPage = """
    {
      "products": [\(summary), \(summary.replacingOccurrences(of: "\"id\": 1,", with: "\"id\": 2,"))],
      "total": 194,
      "skip": 40,
      "limit": 2
    }
    """

    /// A list response with two copies of `product` (ids 1 and 2).
    static let page = """
    {
      "products": [\(product), \(product.replacingOccurrences(of: "\"id\": 1,", with: "\"id\": 2,"))],
      "total": 194,
      "skip": 40,
      "limit": 2
    }
    """
}
