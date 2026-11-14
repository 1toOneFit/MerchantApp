import Foundation
import Testing
@testable import MerchantCatalog

private func detail(_ id: Int) -> Route {
    .productDetail(.list(summary(id), source: .catalog))
}

@MainActor
struct RouterTests {
    @Test func startsEmpty() {
        #expect(Router().path == [])
    }

    @Test func pushAppendsRoute() {
        let router = Router()

        router.push(detail(1))
        router.push(detail(2))

        #expect(router.path == [detail(1), detail(2)])
    }

    @Test func showProductDetailPushesTheRoute() {
        let router = Router(path: [detail(1)])
        let route = ProductDetailRoute.list(summary(2), source: .search)

        router.showProductDetail(route)

        #expect(router.path == [detail(1), .productDetail(route)])
    }

    @Test func popRemovesLastRoute() {
        let router = Router(path: [detail(1), detail(2)])

        router.pop()

        #expect(router.path == [detail(1)])
    }

    @Test func popOnEmptyPathIsNoOp() {
        let router = Router()

        router.pop()

        #expect(router.path == [])
    }

    @Test func popToRootClearsPath() {
        let router = Router(path: [detail(1), detail(2), detail(3)])

        router.popToRoot()

        #expect(router.path == [])
    }

    @Test func popToRootOnEmptyPathIsNoOp() {
        let router = Router()

        router.popToRoot()

        #expect(router.path == [])
    }

    /// D-62: a list route carries the list's product and source; a Saved route the snapshot.
    @Test func routeExposesIDAndSource() {
        let snapshot = SavedProduct(summary(9), savedAt: date("2026-11-13T10:00:00Z"))

        #expect(ProductDetailRoute.list(summary(4), source: .search).productID == 4)
        #expect(ProductDetailRoute.list(summary(4), source: .search).source == .search)
        #expect(ProductDetailRoute.saved(snapshot).productID == 9)
        #expect(ProductDetailRoute.saved(snapshot).source == .saved)
        #expect(Route.productDetail(.saved(snapshot)).logDescription == "productDetail(id: 9, source: saved)")
    }
}
