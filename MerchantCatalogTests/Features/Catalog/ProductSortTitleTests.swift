import Testing
@testable import MerchantCatalog

/// The sort menu's copy (ProductSpecification § 4.2): the options' titles, and the short label that
/// always shows the current sort in the toolbar.
struct ProductSortTitleTests {
    @Test(arguments: [
        (ProductSort.defaultOrder, "Default", "Default"),
        (.priceAscending, "Price: Low to High", "Lowest price"),
        (.priceDescending, "Price: High to Low", "Highest price"),
        (.ratingDescending, "Rating: High to Low", "Top rated"),
    ])
    func titlesMatchTheSpec(sort: ProductSort, title: String, shortTitle: String) {
        #expect(sort.title == title)
        #expect(sort.shortTitle == shortTitle)
    }

    @Test func menuListsTheSortsInSpecOrder() {
        #expect(ProductSort.allCases.map(\.title) == ["Default", "Price: Low to High", "Price: High to Low", "Rating: High to Low"])
    }
}
