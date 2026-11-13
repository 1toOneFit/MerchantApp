/// The details header: title, brand when present, category (ProductSpecification § 4.3 item 2).
struct ProductDetailHeader: Equatable {
    let title: String
    let brand: String?
    /// For display: "mens-shirts" reads "Mens Shirts".
    let category: String?

    init(title: String, brand: String?, category: String?) {
        self.title = title
        self.brand = brand
        self.category = category
    }

    init(_ product: Product) {
        self.init(title: product.title, brand: product.brand, category: product.category.map(Self.categoryName))
    }

    /// The API's category slug as words, each starting with a capital letter.
    static func categoryName(_ slug: String) -> String {
        slug.split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
