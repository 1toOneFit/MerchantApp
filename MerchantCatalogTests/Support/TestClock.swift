import Synchronization

/// A clock that only moves when a test calls `advance(by:)`. Pass it where production code takes
/// `any Clock<Duration>` to make `duration_ms` values exact and the search debounce deterministic.
///
/// `sleep` suspends until `advance(by:)` reaches its deadline, or throws `CancellationError` when its
/// task is cancelled. `waitForSleepers(_:)` lets a test wait until code under test has started
/// sleeping before it advances the clock.
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

    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct State {
        var now = Instant(offset: .zero)
        var nextSleepID = 0
        var sleepers: [Int: Sleeper] = [:]
        /// Sleeps whose task was cancelled before they suspended.
        var cancelledSleepIDs: Set<Int> = []
        var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

        /// Removes and returns the waiters whose sleeper count is reached.
        mutating func takeReadyWaiters() -> [CheckedContinuation<Void, Never>] {
            let count = sleepers.count
            let ready = waiters.filter { count >= $0.count }.map(\.continuation)
            waiters.removeAll { count >= $0.count }
            return ready
        }
    }

    /// Continuations are resumed outside the lock.
    private let state = Mutex(State())

    var now: Instant {
        state.withLock { $0.now }
    }

    var minimumResolution: Duration { .zero }

    /// Sleeps currently suspended.
    var sleeperCount: Int {
        state.withLock { $0.sleepers.count }
    }

    /// Moves time forward and wakes every sleep whose deadline is reached, earliest first.
    func advance(by duration: Duration) {
        let due = state.withLock { state in
            state.now = state.now.advanced(by: duration)
            let now = state.now
            let dueIDs = state.sleepers
                .filter { $0.value.deadline <= now }
                .sorted { ($0.value.deadline, $0.key) < ($1.value.deadline, $1.key) }
                .map(\.key)
            return dueIDs.compactMap { state.sleepers.removeValue(forKey: $0)?.continuation }
        }
        due.forEach { $0.resume() }
    }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let id = state.withLock { state in
            state.nextSleepID += 1
            return state.nextSleepID
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let outcome = state.withLock { state -> SleepStart in
                    if state.cancelledSleepIDs.remove(id) != nil {
                        return .cancelled
                    }
                    if deadline <= state.now {
                        return .deadlineReached
                    }
                    state.sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                    return .suspended(readyWaiters: state.takeReadyWaiters())
                }
                switch outcome {
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                case .deadlineReached:
                    continuation.resume()
                case .suspended(let readyWaiters):
                    readyWaiters.forEach { $0.resume() }
                }
            }
        } onCancel: {
            let continuation = state.withLock { state -> CheckedContinuation<Void, any Error>? in
                if let sleeper = state.sleepers.removeValue(forKey: id) {
                    return sleeper.continuation
                }
                state.cancelledSleepIDs.insert(id)
                return nil
            }
            continuation?.resume(throwing: CancellationError())
        }
    }

    /// Returns once at least `count` sleeps are suspended.
    func waitForSleepers(_ count: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let isReady = state.withLock { state in
                guard state.sleepers.count < count else { return true }
                state.waiters.append((count, continuation))
                return false
            }
            if isReady {
                continuation.resume()
            }
        }
    }

    private enum SleepStart {
        case cancelled
        case deadlineReached
        case suspended(readyWaiters: [CheckedContinuation<Void, Never>])
    }
}
