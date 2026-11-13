/// What the catalog needs from `product_card_density_v1` (D-70): this launch's assignment, which
/// decides whether cards show the rating, and the exposure report for the first rendered card.
/// `CatalogConfigurator` builds it from `ExperimentService` and `ExposureTracker`.
@MainActor
struct CardExperiment {
    let assignment: ExperimentAssignment
    private let exposure: ExposureTracker

    init(assignment: ExperimentAssignment, exposure: ExposureTracker) {
        self.assignment = assignment
        self.exposure = exposure
    }

    var variant: ExperimentVariant { assignment.variant }

    /// A card of the list on screen rendered: browse is the catalog grid, search results the search
    /// grid. `ExposureTracker` keeps one exposure per session.
    func cardRendered(in context: ListContext) {
        let surface: ExposureSurface = context == .search ? .searchGrid : .catalogGrid
        exposure.cardRendered(.productCardDensity, assignment: assignment, surface: surface)
    }
}
