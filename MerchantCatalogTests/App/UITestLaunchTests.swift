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

    /// The UI tests rely on these products: in stock, low stock, out of stock, in stock; no images.
    @Test func fixtureHasEveryStockStatus() async throws {
        let page = try await repository.products(sort: .defaultOrder, skip: 0, limit: 20)

        #expect(page.products.map(\.title) == ["Desk Lamp", "Notebook Set", "Travel Mug", "Wireless Mouse"])
        #expect(page.products.map(\.stockStatus) == [.inStock, .lowStock, .outOfStock, .inStock])
        #expect(page.products.allSatisfy { $0.thumbnailURL == nil })
        #expect(page.total == 4)
        #expect(page.skip == 0)
    }

    @Test func fixturePagesLikeTheServer() async throws {
        let page = try await repository.products(sort: .defaultOrder, skip: 2, limit: 2)

        #expect(page.products.map(\.id) == [3, 4])
        #expect(page.total == 4)
        #expect(page.skip == 2)
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
