/// A local A/B experiment (Experiments.md). The raw value is the `experiment_id` analytics sends.
enum Experiment: String, CaseIterable, Sendable {
    /// Rating on the catalog card: `treatment` shows it, `control` doesn't.
    case productCardDensity = "product_card_density_v1"
}

/// An experiment arm; the raw value is the `variant` analytics sends.
enum ExperimentVariant: String, CaseIterable, Sendable {
    case control
    case treatment
}

/// Where a variant came from: the installation's hash, or the DEBUG Diagnostics override.
enum AssignmentSource: String, Sendable {
    case hashed
    case override
}

/// The variant an installation sees in one launch, and why (D-69).
struct ExperimentAssignment: Equatable, Sendable {
    let variant: ExperimentVariant
    let source: AssignmentSource
}
