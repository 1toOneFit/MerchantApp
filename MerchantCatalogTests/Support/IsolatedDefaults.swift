import Foundation

/// A `UserDefaults` suite unique to one test. Swift Testing creates a new suite instance per test,
/// so holding one of these as a stored property isolates every test; the suite is removed when the
/// instance is released.
final class IsolatedDefaults {
    let defaults: UserDefaults
    private let suiteName: String

    init() {
        suiteName = "MerchantCatalogTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("UserDefaults(suiteName:) returned nil for \(suiteName)")
        }
        self.defaults = defaults
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
