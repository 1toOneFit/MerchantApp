import Foundation

/// Local, stable assignment (Experiments.md § Assignment).
///
/// The first `assignment(for:)` of a launch decides, in this order: the DEBUG override (`override`
/// source), the variant stored for this installation, or the hash of the installation id, which is
/// then stored so a later allocation change can't move the user (both `hashed`). The result is kept
/// for the rest of the launch (D-69) and sets `experiment_assignments` with every experiment
/// resolved so far. A stored value that isn't a known variant is re-bucketed (D-73).
///
/// `@MainActor` like the analytics stack it reports to (D-33).
@MainActor
final class LocalExperimentService: ExperimentService {
    private enum Key {
        /// `[experiment id: variant]` for this installation.
        static let assignments = "experiments.assignments"
        #if DEBUG
        /// `[experiment id: variant]`, stored apart from the assignments.
        static let overrides = "diagnostics.experiment_overrides"
        #endif
    }

    private let defaults: UserDefaults
    private let installation: InstallationIDProvider
    private let analytics: any AnalyticsTracking
    /// This launch's assignments.
    private var resolved: [Experiment: ExperimentAssignment] = [:]

    init(defaults: UserDefaults, installation: InstallationIDProvider, analytics: any AnalyticsTracking) {
        self.defaults = defaults
        self.installation = installation
        self.analytics = analytics
    }

    func assignment(for experiment: Experiment) -> ExperimentAssignment {
        if let assignment = resolved[experiment] {
            return assignment
        }
        let assignment = resolve(experiment)
        resolved[experiment] = assignment
        Log.experiment.info("\(experiment.rawValue, privacy: .public): \(assignment.variant.rawValue, privacy: .public) (\(assignment.source.rawValue, privacy: .public))")
        analytics.setUserProperty(.experimentAssignments(
            Dictionary(uniqueKeysWithValues: resolved.map { ($0.key.rawValue, $0.value.variant.rawValue) })
        ))
        return assignment
    }

    private func resolve(_ experiment: Experiment) -> ExperimentAssignment {
        #if DEBUG
        if let variant = override(for: experiment) {
            return ExperimentAssignment(variant: variant, source: .override)
        }
        #endif
        var stored = storedVariants(forKey: Key.assignments)
        if let variant = stored[experiment.rawValue].flatMap(ExperimentVariant.init(rawValue:)) {
            return ExperimentAssignment(variant: variant, source: .hashed)
        }
        let variant = ExperimentAssigner.variant(for: experiment, installationID: installation.installationID)
        stored[experiment.rawValue] = variant.rawValue
        defaults.set(stored, forKey: Key.assignments)
        return ExperimentAssignment(variant: variant, source: .hashed)
    }

    private func storedVariants(forKey key: String) -> [String: String] {
        defaults.dictionary(forKey: key) as? [String: String] ?? [:]
    }
}

#if DEBUG
extension LocalExperimentService: ExperimentOverrides {
    func override(for experiment: Experiment) -> ExperimentVariant? {
        storedVariants(forKey: Key.overrides)[experiment.rawValue].flatMap(ExperimentVariant.init(rawValue:))
    }

    func setOverride(_ variant: ExperimentVariant?, for experiment: Experiment) {
        var overrides = storedVariants(forKey: Key.overrides)
        overrides[experiment.rawValue] = variant?.rawValue
        defaults.set(overrides, forKey: Key.overrides)
        Log.experiment.info("\(experiment.rawValue, privacy: .public) override: \(variant?.rawValue ?? "auto", privacy: .public) (next launch)")
    }

    func clearStoredAssignments() {
        defaults.removeObject(forKey: Key.assignments)
        Log.experiment.info("stored assignments cleared (next launch)")
    }
}
#endif
