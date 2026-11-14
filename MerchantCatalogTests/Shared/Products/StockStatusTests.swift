import Testing
@testable import MerchantCatalog

/// The one stock-status policy (D-84): 0 → Out of stock, 1–10 → Low stock, > 10 → In stock.
struct StockStatusTests {
    @Test(arguments: [
        (-1, StockStatus.outOfStock),
        (0, .outOfStock),
        (1, .lowStock),
        (10, .lowStock),
        (11, .inStock),
        (99, .inStock),
    ])
    func policy(stock: Int, expected: StockStatus) {
        #expect(StockStatus(stock: stock) == expected)
    }

    /// Review Focus 3: a product whose stock the API didn't send has no status at all.
    @Test func unknownStockHasNoStatus() {
        #expect(StockStatus(stock: nil) == nil)
    }

    @Test func lowStockLimitIsTen() {
        #expect(StockStatus.lowStockLimit == 10)
    }

    @Test(arguments: [(StockStatus.outOfStock, true), (.lowStock, true), (.inStock, false)])
    func needsAttention(status: StockStatus, expected: Bool) {
        #expect(status.needsAttention == expected)
    }

    /// The details view event's `availability` values (Analytics.md § 2).
    @Test(arguments: [(StockStatus.outOfStock, "out_of_stock"), (.lowStock, "low_stock"), (.inStock, "in_stock")])
    func analyticsValue(status: StockStatus, expected: String) {
        #expect(status.analyticsValue == expected)
    }

    /// A full product's status comes from its stock, like a list item's.
    @Test func productStatusComesFromStock() {
        #expect(makeProduct(id: 1, stock: 4).stockStatus == .lowStock)
        #expect(makeProduct(id: 1).stockStatus == nil)
    }
}
