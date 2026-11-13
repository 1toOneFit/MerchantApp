import Synchronization
import Testing

/// A clock that only moves when a test calls `advance(by:)`. Pass it where production code takes
/// `any Clock<Duration>` to make `duration_ms` values exact.
final class TestClock: Clock, Sendable {
    struct Instant: InstantProtocol {
        let offset: Duration

        func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Duration {
            other.offset - offset
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    private let current = Mutex(Instant(offset: .zero))

    var now: Instant {
        current.withLock { $0 }
    }

    var minimumResolution: Duration { .zero }

    func advance(by duration: Duration) {
        current.withLock { $0 = $0.advanced(by: duration) }
    }

    /// Nothing sleeps on a clock yet; S3's debounce adds deterministic sleeping here.
    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        Issue.record("TestClock.sleep isn't supported yet")
        throw CancellationError()
    }
}
