import Testing
@testable import MerchantCatalog

private func detail(_ id: Int) -> Route {
    .productDetail(productID: id)
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
}
