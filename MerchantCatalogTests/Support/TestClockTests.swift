import Testing

/// `TestClock` sleeps until a test advances it, so the search debounce is deterministic (D-40).
struct TestClockTests {
    @Test func sleepEndsAtTheDeadline() async throws {
        let clock = TestClock()
        let sleeper = Task { try await clock.sleep(for: .milliseconds(300)) }

        await clock.waitForSleepers(1)
        clock.advance(by: .milliseconds(299))
        #expect(clock.sleeperCount == 1)

        clock.advance(by: .milliseconds(1))
        try await sleeper.value
        #expect(clock.sleeperCount == 0)
    }

    @Test func cancelledSleepThrows() async {
        let clock = TestClock()
        let sleeper = Task { try await clock.sleep(for: .milliseconds(300)) }
        await clock.waitForSleepers(1)

        sleeper.cancel()

        await #expect(throws: CancellationError.self) { try await sleeper.value }
        #expect(clock.sleeperCount == 0)
    }

    @Test func sleepCancelledBeforeItStartsThrows() async {
        let clock = TestClock()
        let sleeper = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await clock.sleep(for: .milliseconds(300))
        }

        await #expect(throws: CancellationError.self) { try await sleeper.value }
        #expect(clock.sleeperCount == 0)
    }

    @Test func pastDeadlineReturnsAtOnce() async throws {
        let clock = TestClock()
        let deadline = clock.now
        clock.advance(by: .milliseconds(10))

        try await clock.sleep(until: deadline, tolerance: nil)

        #expect(clock.sleeperCount == 0)
    }
}
