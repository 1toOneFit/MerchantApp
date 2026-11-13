import Foundation

/// The anonymous installation id (Analytics.md § 2): a random UUID created on first launch and kept
/// in `UserDefaults`, so it survives relaunches and updates but not a reinstall. It is not the
/// IDFA or IDFV. `firstSeenDate` is when the current id was created.
///
/// `@MainActor` like the rest of the analytics stack (D-33): every reader is main-actor code.
@MainActor
final class InstallationIDProvider {
    private enum Key {
        static let installationID = "analytics.installation_id"
        static let firstSeenDate = "analytics.first_seen_date"
    }

    private(set) var installationID: UUID
    private(set) var firstSeenDate: Date

    private let defaults: UserDefaults
    private let now: () -> Date
    private let makeID: () -> UUID

    /// Loads the stored id, or creates and stores one when it is missing or not a UUID.
    init(
        defaults: UserDefaults,
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.defaults = defaults
        self.now = now
        self.makeID = makeID

        if let stored = defaults.string(forKey: Key.installationID).flatMap(UUID.init(uuidString:)) {
            installationID = stored
            if let storedDate = defaults.object(forKey: Key.firstSeenDate) as? Date {
                firstSeenDate = storedDate
            } else {
                firstSeenDate = now()
                defaults.set(firstSeenDate, forKey: Key.firstSeenDate)
            }
        } else {
            installationID = makeID()
            firstSeenDate = now()
            persist()
        }
    }

    /// DEBUG Diagnostics "Reset installation ID" (D-34): a new id and first-seen date, as after a
    /// reinstall.
    func reset() {
        installationID = makeID()
        firstSeenDate = now()
        persist()
    }

    private func persist() {
        defaults.set(installationID.uuidString, forKey: Key.installationID)
        defaults.set(firstSeenDate, forKey: Key.firstSeenDate)
    }
}
