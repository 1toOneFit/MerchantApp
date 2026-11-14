#if DEBUG
import Foundation
@testable import MerchantCatalog

struct FakeLogReaderError: LocalizedError {
    var errorDescription: String? { "log store unavailable" }
}

/// Returns a fixed result instead of reading `OSLogStore`.
struct FakeLogReader: LogReading {
    let result: Result<[LogEntry], FakeLogReaderError>

    func recentEntries() async throws -> [LogEntry] {
        try result.get()
    }
}
#endif
