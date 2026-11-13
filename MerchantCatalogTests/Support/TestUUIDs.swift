import Foundation

/// A readable, fixed UUID: `uuid(1)` is `00000000-0000-0000-0000-000000000001`.
func uuid(_ number: Int) -> UUID {
    let text = String(format: "00000000-0000-0000-0000-%012d", number)
    guard let value = UUID(uuidString: text) else {
        preconditionFailure("invalid test UUID \(text)")
    }
    return value
}

/// Hands out `uuid(1)`, `uuid(2)`, … in order; pass `next` where production code takes `() -> UUID`.
@MainActor
final class SequentialUUIDs {
    private(set) var count = 0

    var next: () -> UUID {
        {
            self.count += 1
            return uuid(self.count)
        }
    }
}
