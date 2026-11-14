import XCTest

/// End-to-end flows on fixed data (D-88). The app is launched with `-ui-testing`, so it shows
/// `FixtureProductRepository`'s four products and never calls the live API:
///
/// | id | Title          | Stock | Status       |
/// |----|----------------|-------|--------------|
/// | 1  | Desk Lamp      | 42    | In stock     |
/// | 2  | Notebook Set   | 4     | Low stock    |
/// | 3  | Travel Mug     | 0     | Out of stock |
/// | 4  | Wireless Mouse | 15    | In stock     |
///
/// Elements are found by accessibility identifier. Two exceptions, because the system controls
/// take no identifier from SwiftUI: the search field (the screen's only one) and the Saved tab
/// (by its title).
@MainActor
final class CatalogUITests: XCTestCase {
    private func launchApp() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func card(_ id: Int, in app: XCUIApplication) -> XCUIElement {
        element("catalog.productCard.\(id)", in: app)
    }

    /// Waits until `element` no longer exists.
    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval = 10) {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        wait(for: [gone], timeout: timeout)
    }

    /// The catalog launches with its products and the Needs attention count of the fixture's two
    /// low and out-of-stock products.
    func testLaunchShowsCatalogAndNeedsAttention() {
        let app = launchApp()

        XCTAssertTrue(card(1, in: app).waitForExistence(timeout: 15))
        XCTAssertTrue(card(2, in: app).exists)
        let needsAttention = app.buttons["catalog.needsAttention"]
        XCTAssertTrue(needsAttention.exists)
        XCTAssertEqual(needsAttention.value as? String, "2 products")
        XCTAssertTrue(app.buttons["catalog.allProducts"].isSelected)
        XCTAssertFalse(needsAttention.isSelected)
    }

    /// Needs attention lists the low and out-of-stock products only; All products brings the rest
    /// back.
    func testNeedsAttentionShowsOnlyLowAndOutOfStock() {
        let app = launchApp()
        XCTAssertTrue(card(1, in: app).waitForExistence(timeout: 15))

        app.buttons["catalog.needsAttention"].tap()

        waitForDisappearance(of: card(1, in: app))
        XCTAssertTrue(card(2, in: app).exists, "low stock")
        XCTAssertTrue(card(3, in: app).exists, "out of stock")
        XCTAssertFalse(card(4, in: app).exists, "in stock")
        XCTAssertTrue(app.buttons["catalog.needsAttention"].isSelected)
        XCTAssertEqual(element("catalog.attentionCoverage", in: app).label, "Based on all 4 products.")

        app.buttons["catalog.allProducts"].tap()

        XCTAssertTrue(card(1, in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(card(4, in: app).exists)
    }

    /// Tapping a card opens its details with the title and the stock status up front.
    func testProductDetailShowsTitleAndStock() {
        let app = launchApp()
        let notebook = card(2, in: app)
        XCTAssertTrue(notebook.waitForExistence(timeout: 15))

        notebook.tap()

        let title = element("productDetail.title", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Notebook Set")
        let stock = element("productDetail.stockStatus", in: app)
        XCTAssertTrue(stock.exists)
        XCTAssertEqual(stock.label, "Low stock, 4 left")
        XCTAssertTrue(element("productDetail.price", in: app).exists)
    }

    /// Typing a query replaces the catalog with the matching product.
    func testSearchFiltersCatalog() {
        let app = launchApp()
        XCTAssertTrue(card(1, in: app).waitForExistence(timeout: 15))
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.tap()
        searchField.typeText("mug")

        // The browse grid stays underneath, hidden from accessibility, while results show (D-47).
        waitForDisappearance(of: card(1, in: app))
        XCTAssertTrue(card(3, in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(card(2, in: app).exists)
        XCTAssertFalse(card(4, in: app).exists)
    }

    /// Saving from details puts the product in the Saved tab.
    func testSaveFromDetailsShowsInSaved() {
        let app = launchApp()
        let lamp = card(1, in: app)
        XCTAssertTrue(lamp.waitForExistence(timeout: 15))
        lamp.tap()
        let save = app.buttons["productDetail.saveButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        wait(for: [enabled], timeout: 10)

        save.tap()
        app.tabBars.buttons["Saved"].tap()

        XCTAssertTrue(element("saved.row.1", in: app).waitForExistence(timeout: 5))
    }
}
