import Foundation

/// Parses an ISO 8601 UTC timestamp such as `2026-11-13T10:00:00Z`.
func date(_ iso8601: String) -> Date {
    do {
        return try Date(iso8601, strategy: .iso8601)
    } catch {
        preconditionFailure("invalid ISO 8601 date \(iso8601): \(error)")
    }
}

/// A controllable wall clock: pass `now` where production code takes `() -> Date`.
@MainActor
final class TestNow {
    var date: Date

    init(_ date: Date = MerchantCatalogTests.date("2026-11-13T10:00:00Z")) {
        self.date = date
    }

    func advance(by seconds: TimeInterval) {
        date += seconds
    }

    var now: () -> Date {
        { self.date }
    }
}
