import Foundation
import Testing
@testable import MerchantCatalog

/// `product_card_density_v1` on the catalog (Experiments.md, D-70): the cards carry the rating only
/// in treatment, and the first card of the list on screen reports exposure with its surface.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CatalogViewModelExperimentTests {
    private let repository = FakeProductRepository()
    private let analytics = SpyAnalytics()
    private let clock = TestClock()
    private let store = IsolatedDefaults()
    private let sessions: SessionTracker

    init() {
        sessions = SessionTracker(defaults: store.defaults)
        _ = sessions.startSession(kind: .cold, at: date("2026-11-13T10:00:00Z"))
    }

    private static func assignment(_ variant: ExperimentVariant) -> ExperimentAssignment {
        ExperimentAssignment(variant: variant, source: .hashed)
    }

    /// Products `ids`, each rated `4 + id / 100`.
    private func ratedPage(_ ids: ClosedRange<Int>, total: Int, skip: Int) -> ProductPage {
        let products = ids.map { makeProduct(id: $0, rating: 4 + Double($0) / 100) }
        return ProductPage(products: products, total: total, skip: skip, limit: ids.count)
    }

    private func makeViewModel(_ variant: ExperimentVariant) -> CatalogViewModel {
        CatalogViewModel(
            repository: repository,
            analytics: analytics,
            router: Router(),
            savedProducts: SavedProductsStore(repository: InMemorySavedRepository(), analytics: SpyAnalytics()),
            cardExperiment: CardExperiment(
                assignment: Self.assignment(variant),
                exposure: ExposureTracker(analytics: analytics, sessions: sessions)
            ),
            clock: clock
        )
    }

    /// Browsing rated products 1...20 of 194, with the analytics so far cleared.
    private func browsingViewModel(_ variant: ExperimentVariant) async -> CatalogViewModel {
        repository.enqueue(ratedPage(1...20, total: 194, skip: 0))
        let viewModel = makeViewModel(variant)
        await viewModel.start()
        analytics.reset()
        return viewModel
    }

    /// Searches "phone", answered with rated products 101...105, and clears the analytics.
    private func search(in viewModel: CatalogViewModel) async {
        repository.enqueue(ratedPage(101...105, total: 5, skip: 0))
        viewModel.searchTextChanged(to: "phone")
        await clock.waitForSleepers(1)
        clock.advance(by: CatalogViewModel.searchDebounce)
        await viewModel.searchTask?.value
        analytics.reset()
    }

    private var exposures: [AnalyticsEvent] {
        analytics.events.filter { $0.name == .experimentExposed }
    }

    @Test func treatmentCardsCarryTheRating() async {
        let viewModel = await browsingViewModel(.treatment)
        #expect(viewModel.browseList.cards.first?.rating == 4.01)
        #expect(viewModel.browseList.cards.allSatisfy { $0.rating != nil })

        await search(in: viewModel)

        #expect(viewModel.searchList?.cards.first?.rating == 5.01)
    }

    @Test func controlCardsHaveNoRating() async {
        let viewModel = await browsingViewModel(.control)
        await search(in: viewModel)

        #expect(viewModel.browseList.cards.allSatisfy { $0.rating == nil })
        #expect(viewModel.searchList?.cards.allSatisfy { $0.rating == nil } == true)
    }

    @Test(arguments: ExperimentVariant.allCases)
    func firstBrowseCardExposesCatalogGrid(variant: ExperimentVariant) async {
        let viewModel = await browsingViewModel(variant)

        viewModel.itemAppeared(id: 1, in: .browse)

        #expect(exposures == [.experimentExposed(experiment: .productCardDensity, assignment: Self.assignment(variant), surface: .catalogGrid)])
    }

    @Test func firstSearchCardExposesSearchGrid() async {
        let viewModel = await browsingViewModel(.treatment)
        await search(in: viewModel)

        viewModel.itemAppeared(id: 101, in: .search)

        #expect(exposures == [.experimentExposed(experiment: .productCardDensity, assignment: Self.assignment(.treatment), surface: .searchGrid)])
    }

    /// The browse layer stays in the hierarchy, hidden, under search results (D-47): its cards
    /// aren't seen, so they don't expose.
    @Test func hiddenListCardDoesNotExpose() async {
        let viewModel = await browsingViewModel(.treatment)
        await search(in: viewModel)

        viewModel.itemAppeared(id: 1, in: .browse)

        #expect(exposures.isEmpty)
    }

    /// No card has rendered while page 1 is loading or failed (Experiments.md: a failed initial
    /// load is not exposure).
    @Test func cardOfUnloadedListDoesNotExpose() async {
        repository.enqueue(failure: AppError.offline)
        let viewModel = makeViewModel(.treatment)

        viewModel.itemAppeared(id: 1, in: .browse)
        await viewModel.start()
        viewModel.itemAppeared(id: 1, in: .browse)

        #expect(viewModel.phase == .failed(.offline))
        #expect(exposures.isEmpty)
    }

    @Test func exposureIsOncePerSession() async {
        let viewModel = await browsingViewModel(.control)

        viewModel.itemAppeared(id: 1, in: .browse)
        viewModel.itemAppeared(id: 2, in: .browse)
        #expect(exposures.count == 1)
        await search(in: viewModel)

        viewModel.itemAppeared(id: 101, in: .search)

        #expect(exposures.isEmpty)
    }
}
