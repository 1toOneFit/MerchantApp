import Foundation
import Testing
@testable import MerchantCatalog

/// Assignment, persistence and the DEBUG override (Experiments.md § Assignment, D-69, D-72, D-73).
/// `uuid(1)` buckets to control and `uuid(0)` to treatment (`ExperimentAssignerTests`).
@MainActor
struct LocalExperimentServiceTests {
    private let store = IsolatedDefaults()
    private let analytics = SpyAnalytics()

    private static let assignmentsKey = "experiments.assignments"

    private func installation(_ id: UUID) -> InstallationIDProvider {
        InstallationIDProvider(defaults: store.defaults, makeID: { id })
    }

    /// A new service on the same defaults: what the next launch sees.
    private func service(_ installation: InstallationIDProvider) -> LocalExperimentService {
        LocalExperimentService(defaults: store.defaults, installation: installation, analytics: analytics)
    }

    private var storedAssignments: [String: String]? {
        store.defaults.dictionary(forKey: Self.assignmentsKey) as? [String: String]
    }

    @Test func hashedAssignmentIsStored() {
        let assignment = service(installation(uuid(1))).assignment(for: .productCardDensity)

        #expect(assignment == ExperimentAssignment(variant: .control, source: .hashed))
        #expect(storedAssignments == ["product_card_density_v1": "control"])
    }

    /// A stored variant wins over the hash, so a later allocation change can't move the user.
    @Test func storedAssignmentIsReused() {
        store.defaults.set(["product_card_density_v1": "treatment"], forKey: Self.assignmentsKey)

        let assignment = service(installation(uuid(1))).assignment(for: .productCardDensity)

        #expect(assignment == ExperimentAssignment(variant: .treatment, source: .hashed))
    }

    @Test func unknownStoredVariantIsReassigned() {
        store.defaults.set(["product_card_density_v1": "blue"], forKey: Self.assignmentsKey)

        let assignment = service(installation(uuid(1))).assignment(for: .productCardDensity)

        #expect(assignment == ExperimentAssignment(variant: .control, source: .hashed))
        #expect(storedAssignments == ["product_card_density_v1": "control"])
    }

    @Test func assignmentSetsTheUserProperty() {
        _ = service(installation(uuid(0))).assignment(for: .productCardDensity)

        #expect(analytics.userProperties == [.experimentAssignments(["product_card_density_v1": "treatment"])])
    }

    #if DEBUG
    /// D-69: an override changed during a launch applies at the next launch.
    @Test func assignmentIsResolvedOncePerLaunch() {
        let installation = installation(uuid(1))
        let current = service(installation)
        _ = current.assignment(for: .productCardDensity)

        current.setOverride(.treatment, for: .productCardDensity)

        #expect(current.assignment(for: .productCardDensity) == ExperimentAssignment(variant: .control, source: .hashed))
        #expect(analytics.userProperties.count == 1)
        #expect(service(installation).assignment(for: .productCardDensity) == ExperimentAssignment(variant: .treatment, source: .override))
    }

    @Test func overrideWinsAndKeepsTheStoredAssignment() {
        let installation = installation(uuid(1))
        _ = service(installation).assignment(for: .productCardDensity)
        service(installation).setOverride(.treatment, for: .productCardDensity)

        let overridden = service(installation)
        #expect(overridden.assignment(for: .productCardDensity) == ExperimentAssignment(variant: .treatment, source: .override))
        #expect(overridden.override(for: .productCardDensity) == .treatment)
        #expect(storedAssignments == ["product_card_density_v1": "control"])
        #expect(analytics.userProperties.last == .experimentAssignments(["product_card_density_v1": "treatment"]))

        service(installation).setOverride(nil, for: .productCardDensity)

        #expect(service(installation).assignment(for: .productCardDensity) == ExperimentAssignment(variant: .control, source: .hashed))
    }

    /// The installation reset clears stored assignments; the next launch buckets the new id.
    @Test func resetRebucketsWithTheNewID() {
        var ids = [uuid(1), uuid(0)]
        let installation = InstallationIDProvider(defaults: store.defaults, makeID: { ids.removeFirst() })
        #expect(service(installation).assignment(for: .productCardDensity).variant == .control)

        installation.reset()
        service(installation).clearStoredAssignments()

        #expect(storedAssignments == nil)
        #expect(service(installation).assignment(for: .productCardDensity) == ExperimentAssignment(variant: .treatment, source: .hashed))
    }

    /// D-72: the override is a developer setting, kept across the reset.
    @Test func overrideSurvivesClearingAssignments() {
        let installation = installation(uuid(1))
        service(installation).setOverride(.treatment, for: .productCardDensity)

        service(installation).clearStoredAssignments()

        #expect(service(installation).override(for: .productCardDensity) == .treatment)
    }
    #endif
}
