import Foundation
import Testing
@testable import MerchantCatalog

private func detail(_ id: Int) -> Route {
    .productDetail(ProductDetailRoute(productID: id, source: .catalog))
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
        let route = ProductDetailRoute(productID: 2, source: .search)

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

    /// D-83: a details route is the product's id and where it was opened from, for every source;
    /// details load everything else.
    @Test func routeIsTheIDAndSource() {
        let route = ProductDetailRoute(productID: 9, source: .saved)

        #expect(route.productID == 9)
        #expect(route.source == .saved)
        #expect(Route.productDetail(route).logDescription == "productDetail(id: 9, source: saved)")
    }
}
