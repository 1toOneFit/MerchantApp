import Synchronization

/// An artificial server-side delay added to every API request as `delay=<ms>` (Networking.md A8).
/// Only the DEBUG slow-network toggle sets it; Release builds never do.
///
/// A `Mutex` makes it safe to read from `URLSessionAPIClient`, which runs off the main actor,
/// while the Diagnostics screen changes it on the main actor.
final class RequestDelay: Sendable {
    private let storage: Mutex<Duration?>

    init(_ value: Duration? = nil) {
        storage = Mutex(value)
    }

    var value: Duration? {
        storage.withLock { $0 }
    }

    func set(_ value: Duration?) {
        storage.withLock { $0 = value }
    }
}
