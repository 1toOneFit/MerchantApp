import Testing
@testable import MerchantCatalog

/// A controllable `ProductRepository`. Results queued with `enqueue` answer requests in order; a
/// request with nothing queued suspends until the test calls `resumeNext(with:)`, which lets tests
/// observe in-flight states and out-of-order completion. Single-product requests (`product(id:)`)
/// have their own queue (`enqueueProduct`, `resumeNextProduct`). Main-actor isolated, so tests read
/// and change it without locks.
@MainActor
final class FakeProductRepository: ProductRepository {
    struct Request: Equatable {
        /// `nil` for a catalog page, the query for a search.
        var query: String? = nil
        let sort: ProductSort
        let skip: Int
        let limit: Int
    }

    private(set) var requests: [Request] = []
    /// Requests whose calling task was cancelled by the time they returned.
    private(set) var cancelledRequestCount = 0
    /// Runs as each request arrives, before it is answered (e.g. to advance a `TestClock`).
    var onRequest: (() -> Void)?

    private var queued: [Result<ProductPage, any Error>] = []
    private var pending: [CheckedContinuation<ProductPage, any Error>] = []
    private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    var pendingCount: Int { pending.count }

    /// Ids of `product(id:)` requests, in order.
    private(set) var productRequests: [Int] = []
    private var queuedProducts: [Result<Product, any Error>] = []
    private var pendingProducts: [CheckedContinuation<Product, any Error>] = []
    private var productWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    var pendingProductCount: Int { pendingProducts.count }

    func enqueueProduct(_ result: Result<Product, any Error>) {
        queuedProducts.append(result)
    }

    func product(id: Product.ID) async throws -> Product {
        productRequests.append(id)
        defer {
            if Task.isCancelled { cancelledRequestCount += 1 }
        }
        if !queuedProducts.isEmpty {
            return try queuedProducts.removeFirst().get()
        }
        return try await withCheckedThrowingContinuation { continuation in
            pendingProducts.append(continuation)
            let ready = productWaiters.filter { pendingProducts.count >= $0.count }
            productWaiters.removeAll { pendingProducts.count >= $0.count }
            ready.forEach { $0.continuation.resume() }
        }
    }

    /// Answers the oldest suspended `product(id:)` request.
    func resumeNextProduct(with result: Result<Product, any Error>) {
        guard !pendingProducts.isEmpty else {
            Issue.record("FakeProductRepository: no suspended product request to resume")
            return
        }
        pendingProducts.removeFirst().resume(with: result)
    }

    /// Returns once at least `count` `product(id:)` requests are suspended.
    func waitForPendingProductRequests(_ count: Int) async {
        guard pendingProducts.count < count else { return }
        await withCheckedContinuation { continuation in
            productWaiters.append((count, continuation))
        }
    }

    func enqueue(_ page: ProductPage) {
        queued.append(.success(page))
    }

    func enqueue(failure error: any Error) {
        queued.append(.failure(error))
    }

    func products(sort: ProductSort, skip: Int, limit: Int) async throws -> ProductPage {
        try await answer(Request(sort: sort, skip: skip, limit: limit))
    }

    func search(query: String, sort: ProductSort, skip: Int, limit: Int) async throws -> ProductPage {
        try await answer(Request(query: query, sort: sort, skip: skip, limit: limit))
    }

    private func answer(_ request: Request) async throws -> ProductPage {
        requests.append(request)
        defer {
            if Task.isCancelled { cancelledRequestCount += 1 }
        }
        onRequest?()
        if !queued.isEmpty {
            return try queued.removeFirst().get()
        }
        return try await withCheckedThrowingContinuation { continuation in
            pending.append(continuation)
            resumeWaiters()
        }
    }

    /// Answers the oldest suspended request.
    func resumeNext(with result: Result<ProductPage, any Error>) {
        guard !pending.isEmpty else {
            Issue.record("FakeProductRepository: no suspended request to resume")
            return
        }
        pending.removeFirst().resume(with: result)
    }

    /// Answers the most recently suspended request, so a newer request can finish before an older one.
    func resumeNewest(with result: Result<ProductPage, any Error>) {
        guard !pending.isEmpty else {
            Issue.record("FakeProductRepository: no suspended request to resume")
            return
        }
        pending.removeLast().resume(with: result)
    }

    /// Returns once at least `count` requests are suspended.
    func waitForPendingRequests(_ count: Int) async {
        guard pending.count < count else { return }
        await withCheckedContinuation { continuation in
            waiters.append((count, continuation))
        }
    }

    private func resumeWaiters() {
        let ready = waiters.filter { pending.count >= $0.count }
        waiters.removeAll { pending.count >= $0.count }
        ready.forEach { $0.continuation.resume() }
    }
}
