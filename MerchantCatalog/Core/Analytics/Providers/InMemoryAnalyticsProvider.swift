#if DEBUG
import Observation

/// DEBUG-only provider behind the Diagnostics sheet: keeps the most recent events (bounded, oldest
/// dropped first) and the current value of every user property.
@MainActor
@Observable
final class InMemoryAnalyticsProvider: AnalyticsProvider {
    static let defaultCapacity = 500

    /// Oldest first, at most `capacity` entries.
    private(set) var events: [AnalyticsEnvelope] = []
    private(set) var userProperties: [String: AnalyticsValue] = [:]

    private let capacity: Int

    init(capacity: Int = InMemoryAnalyticsProvider.defaultCapacity) {
        precondition(capacity > 0, "InMemoryAnalyticsProvider needs a positive capacity")
        self.capacity = capacity
    }

    func send(_ envelope: AnalyticsEnvelope) {
        events.append(envelope)
        if events.count > capacity {
            events.removeFirst(events.count - capacity)
        }
    }

    func userPropertyDidChange(_ change: UserPropertyChange) {
        userProperties[change.name] = change.newValue
    }
}
#endif
