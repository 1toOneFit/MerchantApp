import Testing
@testable import MerchantCatalog

/// Load durations (`duration_ms`) come from an injected monotonic clock (D-40).
struct ClockStopwatchTests {
    @Test func stopwatchMeasuresElapsedTime() {
        let clock = TestClock()
        let elapsed = clock.stopwatch()

        clock.advance(by: .milliseconds(250))

        #expect(elapsed() == .milliseconds(250))
    }

    /// Works through the existential the view model stores.
    @Test func stopwatchWorksOnAnyClock() {
        let clock = TestClock()
        let anyClock: any Clock<Duration> = clock
        let elapsed = anyClock.stopwatch()

        clock.advance(by: .seconds(2))

        #expect(elapsed() == .seconds(2))
    }

    @Test(arguments: [
        (Duration.milliseconds(1234) + .microseconds(900), 1234),
        (.zero, 0),
        (.seconds(15), 15_000),
        (.milliseconds(-5), 0),
    ])
    func wholeMilliseconds(duration: Duration, expected: Int) {
        #expect(duration.wholeMilliseconds == expected)
    }
}
