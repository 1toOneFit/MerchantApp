#if DEBUG
import Foundation

/// DEBUG "Slow network" (D-42): while on, every API request carries `delay=2000`, so the skeleton
/// and the load-more footer stay visible long enough to check. The choice is persisted, so a
/// relaunch shows the skeleton too. It affects API requests only, not images (Networking.md § 4).
@MainActor
final class SlowNetworkSetting {
    /// The server-side delay added to each request (Networking.md A8).
    static let delay: Duration = .milliseconds(2000)
    private static let key = "diagnostics.slow_network"

    private let defaults: UserDefaults
    private let requestDelay: RequestDelay

    /// - Parameter requestDelay: the delay `URLSessionAPIClient` reads on every request.
    init(defaults: UserDefaults, requestDelay: RequestDelay) {
        self.defaults = defaults
        self.requestDelay = requestDelay
        apply(defaults.bool(forKey: Self.key))
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.key) }
        set {
            defaults.set(newValue, forKey: Self.key)
            apply(newValue)
            Log.network.info("slow network \(newValue ? "on" : "off", privacy: .public)")
        }
    }

    private func apply(_ isEnabled: Bool) {
        requestDelay.set(isEnabled ? Self.delay : nil)
    }
}
#endif
