import Testing
@testable import MerchantCatalog

/// Catalog search (ProductSpecification § 4.2, AC-S1, AC-S2, AC-S4, AC-S5) and its analytics
/// (Analytics.md § 3 Search), with a controllable repository and clock: the debounce sleeps on
/// `TestClock`, so no test waits for real time. The time limit turns a suspended request that is
/// never answered into a failure instead of a hang.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CatalogViewModelSearchTests {
    private let repository = FakeProductRepository()
    private let analytics = SpyAnalytics()
    private let clock = TestClock()

    private func makeViewModel() -> CatalogViewModel {
        CatalogViewModel(repository: repository, analytics: analytics, router: Router(), savedProducts: SavedProductsStore(repository: InMemorySavedRepository(), analytics: SpyAnalytics()), clock: clock)
    }

    /// A view model browsing products 1...20 of 194, with the analytics so far cleared.
    private func browsingViewModel() async -> CatalogViewModel {
        repository.enqueue(page(1...20, total: 194, skip: 0))
        let viewModel = makeViewModel()
        await viewModel.start()
        analytics.reset()
        return viewModel
    }

    /// Waits until the debounce is sleeping, then lets its interval pass.
    private func finishDebounce() async {
        await clock.waitForSleepers(1)
        clock.advance(by: CatalogViewModel.searchDebounce)
    }

    /// Types `text`, lets the debounce pass and waits for the search, answered with `answer`.
    private func search(_ text: String, in viewModel: CatalogViewModel, answer: ProductPage) async {
        repository.enqueue(answer)
        viewModel.searchTextChanged(to: text)
        await finishDebounce()
        await viewModel.searchTask?.value
    }

    // MARK: - Debounce

    /// AC-S1: typing quickly sends one request, for the last query, after typing stops.
    @Test func requestsOnlyTheLastQueryAfterTypingStops() async {
        let viewModel = await browsingViewModel()
        repository.enqueue(page(101...120, total: 23, skip: 0))

        for text in ["p", "ph", "pho", "phon", "phone"] {
            viewModel.searchTextChanged(to: text)
            await clock.waitForSleepers(1)
            clock.advance(by: .milliseconds(100))
        }
        #expect(repository.requests.count == 1, "only the browse page so far")

        clock.advance(by: .milliseconds(200))
        await viewModel.searchTask?.value

        #expect(Array(repository.requests.dropFirst()) == [.init(query: "phone", sort: .defaultOrder, skip: 0, limit: 20)])
    }

    @Test func queryIsTrimmed() async {
        let viewModel = await browsingViewModel()

        await search("  phone  ", in: viewModel, answer: page(101...120, total: 23, skip: 0))

        #expect(repository.requests.last?.query == "phone")
    }

    @Test func whitespaceOnlyStaysInBrowse() async {
        let viewModel = await browsingViewModel()

        viewModel.searchTextChanged(to: "   ")

        #expect(viewModel.searchTask == nil)
        #expect(viewModel.listContext == .browse)
        #expect(analytics.events.isEmpty)
    }

    @Test func trailingSpaceSendsNothing() async {
        let viewModel = await browsingViewModel()
        await search("phone", in: viewModel, answer: page(101...120, total: 23, skip: 0))
        let searchTask = viewModel.searchTask
        analytics.reset()

        viewModel.searchTextChanged(to: "phone ")

        #expect(viewModel.searchText == "phone ")
        #expect(viewModel.searchTask == searchTask, "no new search was scheduled")
        #expect(analytics.events.isEmpty)
    }

    /// D-50: the list on screen stays during the debounce; the committed query shows the skeleton.
    @Test func committedQueryShowsSkeletonThenResults() async {
        let viewModel = await browsingViewModel()
        repository.onRequest = { [clock] in clock.advance(by: .milliseconds(140)) }

        viewModel.searchTextChanged(to: "phone")
        #expect(viewModel.listContext == .browse)
        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))

        await finishDebounce()
        await repository.waitForPendingRequests(1)
        #expect(viewModel.listContext == .search)
        #expect(viewModel.phase == .initialLoading)
        #expect(viewModel.browseList.cards.map(\.id) == Array(1...20), "browse stays loaded underneath")

        repository.resumeNext(with: .success(page(101...120, total: 23, skip: 0)))
        await viewModel.searchTask?.value

        #expect(viewModel.cards.map(\.id) == Array(101...120))
        #expect(viewModel.searchList?.phase == .content(footer: .idle, refreshError: nil))
        #expect(analytics.events == [
            .searchStarted(sort: .defaultOrder),
            .searchPerformed(trigger: .typing, queryLength: 5, wordCount: 1, sort: .defaultOrder, resultCount: 20, totalCount: 23, durationMs: 140),
        ])
    }

    /// Review Focus 2: the old debounce has woken but not run when the user types again.
    @Test func retypingAtTheDeadlineRequestsOnlyTheLatestQuery() async {
        let viewModel = await browsingViewModel()
        // Answers for two requests, so a wrong "ph" request fails the test instead of hanging it.
        repository.enqueue(page(1...3, total: 3, skip: 0))
        repository.enqueue(page(1...3, total: 3, skip: 0))
        viewModel.searchTextChanged(to: "ph")
        await clock.waitForSleepers(1)
        let staleTask = viewModel.searchTask

        clock.advance(by: CatalogViewModel.searchDebounce)
        viewModel.searchTextChanged(to: "pho")
        await staleTask?.value
        await finishDebounce()
        await viewModel.searchTask?.value

        #expect(repository.requests.compactMap(\.query) == ["pho"])
    }

    // MARK: - Stale responses

    /// AC-S2: a slow response for an earlier query never replaces the results of a later one.
    @Test func outOfOrderResponseIsDropped() async {
        let viewModel = await browsingViewModel()
        viewModel.searchTextChanged(to: "ph")
        await finishDebounce()
        await repository.waitForPendingRequests(1)
        let olderTask = viewModel.searchTask

        viewModel.searchTextChanged(to: "pho")
        await finishDebounce()
        await repository.waitForPendingRequests(2)
        let newerTask = viewModel.searchTask

        repository.resumeNewest(with: .success(page(1...3, total: 3, skip: 0)))
        await newerTask?.value
        repository.resumeNext(with: .success(page(4...6, total: 3, skip: 0)))
        await olderTask?.value

        #expect(viewModel.cards.map(\.id) == [1, 2, 3])
        #expect(analytics.events.filter { $0.name == .searchPerformed }.count == 1)
        #expect(repository.cancelledRequestCount == 1, "the newer query cancelled the older request")
    }

    // MARK: - Clearing

    /// AC-S4: clearing returns to the exact browse list, without a request.
    @Test func clearingRestoresBrowseWithoutARequest() async {
        let viewModel = await browsingViewModel()
        repository.enqueue(page(21...40, total: 194, skip: 20))
        viewModel.itemAppeared(id: 20, in: .browse)
        await viewModel.pageTask?.value
        await search("phone", in: viewModel, answer: page(101...120, total: 23, skip: 0))
        let requestCount = repository.requests.count
        analytics.reset()

        viewModel.searchTextChanged(to: "")

        #expect(viewModel.listContext == .browse)
        #expect(viewModel.searchList == nil)
        #expect(viewModel.cards.map(\.id) == Array(1...40))
        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))
        #expect(repository.requests.count == requestCount)
        #expect(analytics.events == [.searchCleared(queryLength: 5, hadResults: true)])
    }

    /// How Cancel reaches the view model: the field's dismissal alone, or with the system also
    /// emptying the text, in either order.
    enum CancelSequence: CaseIterable {
        case dismissalOnly
        case dismissalThenEmptyText
        case emptyTextThenDismissal
    }

    /// Review finding 1: Cancel ends the search however the system reports it: browse again, the
    /// request cancelled, exactly one `search_cleared`.
    @Test(arguments: CancelSequence.allCases)
    func cancelEndsTheSearchOnce(sequence: CancelSequence) async {
        let viewModel = await browsingViewModel()
        viewModel.searchTextChanged(to: "phone")
        await finishDebounce()
        await repository.waitForPendingRequests(1)
        let task = viewModel.searchTask
        analytics.reset()

        switch sequence {
        case .dismissalOnly:
            viewModel.searchDismissed()
        case .dismissalThenEmptyText:
            viewModel.searchDismissed()
            viewModel.searchTextChanged(to: "")
        case .emptyTextThenDismissal:
            viewModel.searchTextChanged(to: "")
            viewModel.searchDismissed()
        }
        repository.resumeNext(with: .success(page(101...120, total: 23, skip: 0)))
        await task?.value

        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.listContext == .browse)
        #expect(viewModel.cards.map(\.id) == Array(1...20))
        #expect(analytics.events == [.searchCleared(queryLength: 5, hadResults: false)])
        #expect(repository.cancelledRequestCount == 1)
    }

    @Test func clearingDuringTheDebounceSendsNothing() async {
        let viewModel = await browsingViewModel()
        viewModel.searchTextChanged(to: "ph")
        await clock.waitForSleepers(1)
        let task = viewModel.searchTask

        viewModel.searchTextChanged(to: "")
        await task?.value
        clock.advance(by: CatalogViewModel.searchDebounce)

        #expect(repository.requests.count == 1)
        #expect(analytics.events == [
            .searchStarted(sort: .defaultOrder),
            .searchCleared(queryLength: 2, hadResults: false),
        ])
    }

    /// Review Focus 3: a response that arrives after clearing never shows and sends nothing.
    @Test func clearingDropsAnInFlightSearch() async {
        let viewModel = await browsingViewModel()
        viewModel.searchTextChanged(to: "phone")
        await finishDebounce()
        await repository.waitForPendingRequests(1)
        let task = viewModel.searchTask

        viewModel.searchTextChanged(to: "")
        repository.resumeNext(with: .success(page(101...120, total: 23, skip: 0)))
        await task?.value

        #expect(viewModel.listContext == .browse)
        #expect(viewModel.cards.map(\.id) == Array(1...20))
        #expect(!analytics.events.contains { $0.name == .searchPerformed })
        #expect(repository.cancelledRequestCount == 1)
    }

    // MARK: - Analytics

    @Test func searchStartedFiresOnceUntilEmpty() {
        let viewModel = makeViewModel()

        for text in ["p", "ph", "p", "", "q"] {
            viewModel.searchTextChanged(to: text)
        }

        #expect(analytics.events == [
            .searchStarted(sort: .defaultOrder),
            .searchCleared(queryLength: 1, hadResults: false),
            .searchStarted(sort: .defaultOrder),
        ])
    }

    /// D-18: length and word count, never the text.
    @Test func performedEventCarriesNoQueryText() async {
        let viewModel = await browsingViewModel()

        await search("red  shoes", in: viewModel, answer: page(1...2, total: 2, skip: 0))

        #expect(analytics.events.last == .searchPerformed(
            trigger: .typing, queryLength: 10, wordCount: 2, sort: .defaultOrder, resultCount: 2, totalCount: 2, durationMs: 0
        ))
        let strings = analytics.events.flatMap { $0.properties.values }.compactMap { value -> String? in
            if case .string(let string) = value { string } else { nil }
        }
        #expect(!strings.contains { $0.contains("red") || $0.contains("shoes") })
    }

    @Test func catalogViewedReportsTheListOnScreen() async {
        let viewModel = await browsingViewModel()
        await search("phone", in: viewModel, answer: page(101...120, total: 23, skip: 0))

        viewModel.catalogBecameVisible()

        #expect(analytics.events.last == .catalogViewed(sort: .defaultOrder, listContext: .search))
    }

    // MARK: - States

    /// AC-S5: no matches show the no-results state, and Clear search returns to browse.
    @Test func noResultsShowsNoResultsState() async {
        let viewModel = await browsingViewModel()

        await search("zzz", in: viewModel, answer: emptyPage(total: 0, skip: 0))

        #expect(viewModel.phase == .noResults(query: "zzz"))
        #expect(analytics.events.last == .searchPerformed(
            trigger: .typing, queryLength: 3, wordCount: 1, sort: .defaultOrder, resultCount: 0, totalCount: 0, durationMs: 0
        ))

        viewModel.clearSearch()

        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.listContext == .browse)
        #expect(viewModel.cards.map(\.id) == Array(1...20))
        #expect(analytics.events.last == .searchCleared(queryLength: 3, hadResults: false))
    }

    @Test func searchFailureShowsErrorAndRetryRecovers() async {
        let viewModel = await browsingViewModel()
        repository.enqueue(failure: AppError.offline)
        viewModel.searchTextChanged(to: "phone")
        await finishDebounce()
        await viewModel.searchTask?.value

        #expect(viewModel.phase == .failed(.offline))
        #expect(analytics.events.last == .searchFailed(trigger: .typing, queryLength: 5, error: .offline))

        repository.enqueue(page(101...120, total: 23, skip: 0))
        viewModel.retry()
        #expect(viewModel.phase == .initialLoading)
        await viewModel.searchTask?.value

        #expect(viewModel.cards.map(\.id) == Array(101...120))
        #expect(repository.requests.last == .init(query: "phone", sort: .defaultOrder, skip: 0, limit: 20))
        #expect(Array(analytics.events.suffix(2)) == [
            .retryRequested(failedSurface: .search, error: .offline),
            .searchPerformed(trigger: .retry, queryLength: 5, wordCount: 1, sort: .defaultOrder, resultCount: 20, totalCount: 23, durationMs: 0),
        ])
    }

    @Test func cancelledSearchSendsNothing() async {
        let viewModel = await browsingViewModel()
        repository.enqueue(failure: CancellationError())

        viewModel.searchTextChanged(to: "phone")
        await finishDebounce()
        await viewModel.searchTask?.value

        #expect(viewModel.phase == .initialLoading)
        #expect(analytics.events == [.searchStarted(sort: .defaultOrder)])
    }

    // MARK: - Browse underneath

    /// Review Focus 4: a browse page in flight when a search starts lands in browse only.
    @Test func browsePageFinishesWhileSearching() async {
        let viewModel = await browsingViewModel()
        viewModel.itemAppeared(id: 20, in: .browse)
        await repository.waitForPendingRequests(1)
        let browsePageTask = viewModel.pageTask

        await search("phone", in: viewModel, answer: page(101...120, total: 23, skip: 0))
        repository.resumeNext(with: .success(page(21...40, total: 194, skip: 20)))
        await browsePageTask?.value

        #expect(viewModel.cards.map(\.id) == Array(101...120))
        viewModel.clearSearch()
        #expect(viewModel.cards.map(\.id) == Array(1...40))
    }

    /// D-52: cards of the hidden browse layer load no page, of either list.
    @Test func hiddenListIgnoresItemAppeared() async {
        let viewModel = await browsingViewModel()
        await search("phone", in: viewModel, answer: page(1...20, total: 23, skip: 0))
        analytics.reset()

        viewModel.itemAppeared(id: 20, in: .browse)

        #expect(analytics.events.isEmpty, "no catalog_page_requested")
        #expect(viewModel.browseList.phase == .content(footer: .idle, refreshError: nil))
        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))
    }

    // MARK: - Pages, refresh, teardown

    /// AC-S3: pages of search results keep the query and the sort.
    @Test func searchPaginatesWithQueryAndSort() async {
        let viewModel = await browsingViewModel()
        await search("phone", in: viewModel, answer: page(101...120, total: 23, skip: 0))
        analytics.reset()
        repository.enqueue(page(121...123, total: 23, skip: 20))

        viewModel.itemAppeared(id: 120, in: .search)
        await viewModel.pageTask?.value

        #expect(repository.requests.last == .init(query: "phone", sort: .defaultOrder, skip: 20, limit: 20))
        #expect(viewModel.cards.map(\.id) == Array(101...123))
        #expect(viewModel.phase == .content(footer: .end, refreshError: nil))
        #expect(analytics.events == [
            .catalogPageRequested(listContext: .search, pageIndex: 2, sort: .defaultOrder, isRetry: false),
            .catalogPageLoaded(listContext: .search, pageIndex: 2, itemCount: 3, hasMore: false, durationMs: 0),
        ])
    }

    @Test func newQueryDropsAnInFlightSearchPage() async {
        let viewModel = await browsingViewModel()
        await search("phone", in: viewModel, answer: page(101...120, total: 23, skip: 0))
        viewModel.itemAppeared(id: 120, in: .search)
        await repository.waitForPendingRequests(1)
        let pageTask = viewModel.pageTask

        await search("phones", in: viewModel, answer: page(201...205, total: 5, skip: 0))
        repository.resumeNext(with: .success(page(121...123, total: 23, skip: 20)))
        await pageTask?.value

        #expect(viewModel.cards.map(\.id) == Array(201...205))
        #expect(!analytics.events.contains { $0.name == .catalogPageLoaded })
        #expect(repository.cancelledRequestCount == 1)
    }

    /// D-48: refreshing search results sends only `catalog_refreshed` with `list_context: search`.
    @Test func refreshWhileSearchingReloadsTheQuery() async {
        let viewModel = await browsingViewModel()
        await search("phone", in: viewModel, answer: page(101...120, total: 23, skip: 0))
        analytics.reset()
        repository.enqueue(page(131...150, total: 23, skip: 0))

        await viewModel.refresh()

        #expect(repository.requests.last == .init(query: "phone", sort: .defaultOrder, skip: 0, limit: 20))
        #expect(viewModel.cards.map(\.id) == Array(131...150))
        #expect(analytics.events == [.catalogRefreshed(listContext: .search, outcome: .success, durationMs: 0)])
    }

    @Test func releasingTheViewModelCancelsTheSearch() async {
        var viewModel: CatalogViewModel? = await browsingViewModel()
        viewModel?.searchTextChanged(to: "phone")
        await finishDebounce()
        await repository.waitForPendingRequests(1)
        let task = viewModel?.searchTask
        weak var released = viewModel

        viewModel = nil

        #expect(released == nil)
        repository.resumeNext(with: .success(page(101...120, total: 23, skip: 0)))
        await task?.value
        #expect(repository.cancelledRequestCount == 1)
        #expect(!analytics.events.contains { $0.name == .searchPerformed })
    }

    @Test func releasingTheViewModelDuringTheDebounceSendsNothing() async {
        var viewModel: CatalogViewModel? = await browsingViewModel()
        viewModel?.searchTextChanged(to: "phone")
        await clock.waitForSleepers(1)
        let task = viewModel?.searchTask

        viewModel = nil

        #expect(clock.sleeperCount == 0, "deinit cancelled the debounce")
        clock.advance(by: CatalogViewModel.searchDebounce)
        await task?.value
        #expect(repository.requests.count == 1)
    }
}
