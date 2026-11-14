#if DEBUG
import Foundation
import Testing
@testable import MerchantCatalog

/// The UI tests' launch path (D-88): `-ui-testing` gives the app a fixed, offline product source
/// with one product of each stock status, so the UI tests never depend on the live API.
@MainActor
struct UITestLaunchTests {
    private let repository = FixtureProductRepository()

    @Test func detectsTheArgument() {
        #expect(UITestLaunch.isRequested(in: ["MerchantCatalog", "-ui-testing"]))
        #expect(!UITestLaunch.isRequested(in: ["MerchantCatalog"]))
        #expect(!UITestLaunch.isRequested(in: ["MerchantCatalog", "-ui-testing-other"]))
    }

    /// The UI tests rely on these products: in stock, low stock, out of stock, in stock, then 20 in
    /// stock that never need attention. 24 products make two pages, so the grid scrolls and Needs
    /// attention can check more. No images.
    @Test func fixtureHasEveryStockStatus() async throws {
        let page = try await repository.products(sort: .defaultOrder, skip: 0, limit: 20)

        #expect(page.products.prefix(4).map(\.title) == ["Desk Lamp", "Notebook Set", "Travel Mug", "Wireless Mouse"])
        #expect(page.products.prefix(4).map(\.stockStatus) == [.inStock, .lowStock, .outOfStock, .inStock])
        #expect(page.products.dropFirst(4).allSatisfy { $0.stockStatus == .inStock })
        #expect(page.products.allSatisfy { $0.thumbnailURL == nil })
        #expect(page.products.count == 20)
        #expect(page.total == 24)
        #expect(page.skip == 0)
    }

    @Test func fixturePagesLikeTheServer() async throws {
        let middle = try await repository.products(sort: .defaultOrder, skip: 2, limit: 2)
        let last = try await repository.products(sort: .defaultOrder, skip: 20, limit: 20)

        #expect(middle.products.map(\.id) == [3, 4])
        #expect(middle.total == 24)
        #expect(middle.skip == 2)
        #expect(last.products.map(\.id) == Array(21...24))
    }

    @Test func fixtureSortsLikeTheServer() async throws {
        let page = try await repository.products(sort: .priceAscending, skip: 0, limit: 20)

        #expect(page.products.map(\.price) == page.products.map(\.price).sorted())
    }

    @Test func fixtureSearchMatchesTheTitle() async throws {
        let page = try await repository.search(query: "MUG", sort: .defaultOrder, skip: 0, limit: 20)

        #expect(page.products.map(\.id) == [3])
        #expect(page.total == 1)
    }

    @Test func fixtureDetailsMatchTheList() async throws {
        let product = try await repository.product(id: 2)

        #expect(product.title == "Notebook Set")
        #expect(product.stock == 4)
        #expect(product.imageURLs.isEmpty)
    }

    @Test func unknownIDIsNotFound() async {
        await #expect(throws: AppError.notFound) {
            try await repository.product(id: 99)
        }
    }

    /// The launch builds the app's context around the fixture, with its own empty saved list.
    @Test func contextUsesTheFixture() {
        let context = UITestLaunch.makeContext()

        #expect(context.container.resolve() as (any ProductRepository)? is FixtureProductRepository)
        #expect(context.savedProducts.items.isEmpty)
    }
}
#endif
