/// Which variant of an experiment this installation sees (Architecture § 4). Callers depend only on
/// this protocol; `LocalExperimentService` is the 1.0 implementation, and a remote-config one could
/// replace it.
@MainActor
protocol ExperimentService: AnyObject {
    /// The assignment for this launch. It doesn't change until the app restarts (D-69), so the
    /// cards, the exposure and `experiment_assignments` always agree.
    func assignment(for experiment: Experiment) -> ExperimentAssignment
}

#if DEBUG
/// DEBUG Diagnostics' control over assignments. Changes are persisted at once and apply at the next
/// launch (D-69). Compiled out of Release builds (Experiments.md § Development override).
@MainActor
protocol ExperimentOverrides: AnyObject {
    /// The persisted override; `nil` is Auto (the hashed assignment).
    func override(for experiment: Experiment) -> ExperimentVariant?
    func setOverride(_ variant: ExperimentVariant?, for experiment: Experiment)
    /// "Reset installation ID": forgets stored assignments, so the next launch buckets the new id.
    /// Overrides are kept (D-72).
    func clearStoredAssignments()
}
#endif
