import Foundation
import Testing
@testable import MerchantCatalog

/// The in-memory source of truth every surface observes (Architecture § 9): newest first, one
/// change at a time, persisted in order, `saved_products_count` kept current (Analytics.md § 2).
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SavedProductsStoreTests {
    private let repository = InMemorySavedRepository()
    private let analytics = SpyAnalytics()
    private let clock = TestNow()

    private func makeStore() -> SavedProductsStore {
        SavedProductsStore(repository: repository, analytics: analytics, now: clock.now)
    }

    private func saved(_ id: Int, at iso: String) -> SavedProduct {
        SavedProduct(summary(id), savedAt: date(iso))
    }

    private func loadedStore() async -> SavedProductsStore {
        let store = makeStore()
        await store.load()
        analytics.reset()
        return store
    }

    @Test func loadsNewestFirstAndSetsCount() async {
        repository.stored = [saved(2, at: "2026-11-10T10:00:00Z"), saved(5, at: "2026-11-12T10:00:00Z")]
        let store = makeStore()

        await store.load()

        #expect(store.items.map(\.id) == [5, 2])
        #expect(store.count == 2)
        #expect(store.isLoaded)
        #expect(store.isSaved(2))
        #expect(!store.isSaved(3))
        #expect(store.item(id: 5) == saved(5, at: "2026-11-12T10:00:00Z"))
        #expect(analytics.userProperties == [.savedProductsCount(2)])
        #expect(repository.writes.isEmpty)
    }

    @Test func loadRunsOnce() async {
        let store = makeStore()

        await store.load()
        await store.load()

        #expect(repository.loadCount == 1)
    }

    @Test func saveReturnsTheChangeAndPersists() async {
        let store = await loadedStore()

        let change = store.save(summary(4))
        await store.writeTask?.value

        let snapshot = SavedProduct(summary(4), savedAt: clock.date)
        #expect(change == .saved(snapshot, countAfter: 1))
        #expect(store.items == [snapshot])
        #expect(repository.writes == [[snapshot]])
        #expect(analytics.userProperties == [.savedProductsCount(1)])
    }

    @Test func newSavesGoFirst() async {
        let store = await loadedStore()

        store.save(summary(1))
        clock.advance(by: 5)
        store.save(summary(2))

        #expect(store.items.map(\.id) == [2, 1])
    }

    @Test func savingASavedProductIsIgnored() async {
        let store = await loadedStore()
        store.save(summary(4))

        #expect(store.save(summary(4)) == nil)
        #expect(store.count == 1)
    }

    @Test func removeReportsTheSavedDuration() async {
        repository.stored = [saved(4, at: "2026-11-13T10:00:00Z")]
        let store = await loadedStore()
        clock.date = date("2026-11-13T10:01:30Z") + 0.9

        let change = store.remove(id: 4)
        await store.writeTask?.value

        #expect(change == .removed(saved(4, at: "2026-11-13T10:00:00Z"), savedDurationS: 90, countAfter: 0))
        #expect(store.items.isEmpty)
        #expect(repository.writes == [[]])
        #expect(analytics.userProperties == [.savedProductsCount(0)])
    }

    @Test func clockMovedBackGivesZeroDuration() async {
        repository.stored = [saved(4, at: "2026-11-13T10:00:00Z")]
        let store = await loadedStore()
        clock.date = date("2026-11-13T09:00:00Z")

        #expect(store.remove(id: 4) == .removed(saved(4, at: "2026-11-13T10:00:00Z"), savedDurationS: 0, countAfter: 0))
    }

    @Test func removingAnUnsavedProductIsIgnored() async {
        let store = await loadedStore()

        #expect(store.remove(id: 9) == nil)
        #expect(repository.writes.isEmpty)
        #expect(analytics.userProperties.isEmpty)
    }

    @Test func countPropertyFollowsChanges() async {
        let store = await loadedStore()

        store.save(summary(1))
        store.save(summary(2))
        store.remove(id: 1)

        #expect(analytics.userProperties == [.savedProductsCount(1), .savedProductsCount(2), .savedProductsCount(1)])
    }

    /// Review Focus 1: fast toggles never leave an older list in the file.
    @Test func writesHappenInOrder() async {
        let store = await loadedStore()
        repository.holdsWrites = true

        store.save(summary(1))
        store.remove(id: 1)
        store.save(summary(2))
        while repository.writes.count < 3 {
            await Task.yield()
            repository.resumeWritesNewestFirst()
        }
        await store.writeTask?.value

        #expect(repository.writes.map { $0.map(\.id) } == [[1], [], [2]])
    }

    /// Review Focus 2: a save made before the launch load finishes is kept and written once, merged
    /// with the stored list; for a product in both, the newer snapshot wins.
    @Test func changesBeforeLoadAreKept() async {
        repository.stored = [saved(2, at: "2026-11-12T10:00:00Z"), saved(3, at: "2026-11-11T10:00:00Z")]
        repository.holdsLoad = true
        let store = makeStore()
        let load = Task { await store.load() }
        await repository.waitForPendingLoad()

        store.save(summary(1))
        clock.advance(by: 5)
        store.save(summary(2))
        #expect(repository.writes.isEmpty, "nothing is written before the stored list is known")
        #expect(analytics.userProperties.isEmpty)

        repository.resumeLoad()
        await load.value
        await store.writeTask?.value

        #expect(store.items.map(\.id) == [2, 1, 3])
        #expect(store.item(id: 2)?.savedAt == clock.date)
        #expect(repository.writes.map { $0.map(\.id) } == [[2, 1, 3]])
        #expect(analytics.userProperties == [.savedProductsCount(3)])
    }
}
