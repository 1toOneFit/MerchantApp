import Testing
@testable import MerchantCatalog

/// How a stock count reads on cards and details (D-84, D-86): the status, plus how many are left
/// when stock is low.
struct StockLabelTests {
    @Test(arguments: [
        (0, StockStatus.outOfStock, "Out of stock", "Out of stock"),
        (1, .lowStock, "Low stock · 1 left", "Low stock, 1 left"),
        (7, .lowStock, "Low stock · 7 left", "Low stock, 7 left"),
        (42, .inStock, "In stock", "In stock"),
    ])
    func text(stock: Int, status: StockStatus, text: String, spoken: String) throws {
        let label = try #require(StockLabel(stock: stock))

        #expect(label.status == status)
        #expect(label.text == text)
        #expect(label.accessibilityText == spoken)
    }

    /// Lays out hidden rows and skeletons; never shown as text.
    @Test func placeholderIsAnInStockLabel() {
        #expect(StockLabel.placeholder == StockLabel(stock: StockStatus.lowStockLimit + 1))
    }

    @Test func unknownStockHasNoLabel() {
        #expect(StockLabel(stock: nil) == nil)
    }
}
