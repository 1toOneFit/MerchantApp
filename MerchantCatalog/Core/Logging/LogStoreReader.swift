#if DEBUG
import Foundation
import OSLog

/// One log entry as the Diagnostics sheet shows it.
struct LogEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let category: String
    let level: String
    let message: String
}

/// Reads this process's recent log entries. DEBUG only; `DiagnosticsViewModel` depends on this
/// protocol so tests don't touch `OSLogStore`.
protocol LogReading: Sendable {
    /// Newest first.
    func recentEntries() async throws -> [LogEntry]
}

/// Reads the app's own entries (subsystem = bundle identifier) from `OSLogStore`.
///
/// Expected platform behavior, not verified by a unit test: the store returns what the system kept
/// for this process. Debug-level messages are normally not stored, so `analytics` and `navigation`
/// entries may be missing here while Console.app (with debug messages included) shows them.
struct OSLogStoreReader: LogReading {
    let subsystem: String
    var maxAge: TimeInterval = 60 * 60
    var limit = 200

    /// Reading the store is blocking I/O, so it runs off the caller's actor.
    @concurrent
    func recentEntries() async throws -> [LogEntry] {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let position = store.position(date: Date.now.addingTimeInterval(-maxAge))
        let predicate = NSPredicate(format: "subsystem == %@", subsystem)
        let entries = try store.getEntries(at: position, matching: predicate)
            .compactMap { $0 as? OSLogEntryLog }
            .suffix(limit)
        return entries.reversed().map { entry in
            LogEntry(
                id: UUID(),
                date: entry.date,
                category: entry.category,
                level: Self.name(of: entry.level),
                message: entry.composedMessage
            )
        }
    }

    private static func name(of level: OSLogEntryLog.Level) -> String {
        switch level {
        case .debug: "debug"
        case .info: "info"
        case .notice: "notice"
        case .error: "error"
        case .fault: "fault"
        case .undefined: "undefined"
        @unknown default: "unknown"
        }
    }
}
#endif
