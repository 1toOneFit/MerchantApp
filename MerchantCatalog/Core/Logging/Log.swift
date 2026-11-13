import Foundation
import OSLog

/// One `Logger` per category (Architecture § 10); subsystem = bundle identifier.
///
/// Interpolate ids, status codes and durations with `privacy: .public`; search terms and product
/// titles with `privacy: .private`. Never log tokens or full payloads.
enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.example.MerchantCatalog"

    /// Launch, scene phase, session start.
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    /// Route pushes and pops, tab changes.
    static let navigation = Logger(subsystem: subsystem, category: "navigation")
    /// HTTP requests and responses.
    static let network = Logger(subsystem: subsystem, category: "network")
    /// Analytics events and user-property changes.
    static let analytics = Logger(subsystem: subsystem, category: "analytics")
    /// Experiment assignment, overrides and exposure.
    static let experiment = Logger(subsystem: subsystem, category: "experiment")
    /// Saved-items load/save and corrupt-file quarantine.
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    /// First-page latency, time to first content.
    static let performance = Logger(subsystem: subsystem, category: "performance")
}
