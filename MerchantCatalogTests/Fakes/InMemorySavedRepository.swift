@testable import MerchantCatalog

/// A controllable `SavedProductsRepository`. `stored` answers `load()`; with `holdsLoad`, a load
/// suspends until `resumeLoad()`. With `holdsWrites`, each write suspends until the test resumes
/// it, so tests can see whether writes overlap; `writes` records each write as it completes.
@MainActor
final class InMemorySavedRepository: SavedProductsRepository {
    var stored: [SavedProduct]
    var holdsLoad = false
    var holdsWrites = false
    private(set) var loadCount = 0
    private(set) var writes: [[SavedProduct]] = []

    private var pendingLoad: CheckedContinuation<Void, Never>?
    private var pendingWrites: [CheckedContinuation<Void, Never>] = []
    private var loadWaiter: CheckedContinuation<Void, Never>?

    init(stored: [SavedProduct] = []) {
        self.stored = stored
    }

    var pendingWriteCount: Int { pendingWrites.count }

    func load() async -> [SavedProduct] {
        loadCount += 1
        if holdsLoad {
            await withCheckedContinuation { continuation in
                pendingLoad = continuation
                loadWaiter?.resume()
                loadWaiter = nil
            }
        }
        return stored
    }

    func save(_ items: [SavedProduct]) async {
        if holdsWrites {
            await withCheckedContinuation { pendingWrites.append($0) }
        }
        stored = items
        writes.append(items)
    }

    /// Returns once a held load is suspended.
    func waitForPendingLoad() async {
        guard pendingLoad == nil else { return }
        await withCheckedContinuation { loadWaiter = $0 }
    }

    func resumeLoad() {
        pendingLoad?.resume()
        pendingLoad = nil
    }

    /// Resumes every held write, newest first: overlapping writes would then complete out of order.
    func resumeWritesNewestFirst() {
        let writes = pendingWrites
        pendingWrites = []
        writes.reversed().forEach { $0.resume() }
    }
}
