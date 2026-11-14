import Foundation
import Testing
@testable import MerchantCatalog

/// `docs/Analytics.md` is the authoritative taxonomy. Every event there is a level-4 heading
/// ``#### `event_name` `` followed by a `- **Status:**` line. Active events must equal
/// `AnalyticsEventName` in code; Planned events must not exist in code yet. Since release 1.0 (S7)
/// every event is Active and events recorded as removed (§ 4) stay out of code.
struct TaxonomyDocumentationTests {
    private struct DocumentedEvent {
        let name: String
        var status: String?
    }

    private static let codeNames = Set(AnalyticsEventName.allCases.map(\.rawValue))

    @Test func activeEventsInDocsMatchCode() throws {
        let events = try Self.documentedEvents()
        let active = Set(events.filter { $0.status == "Active" }.map(\.name))

        #expect(active == Self.codeNames)
    }

    @Test func plannedEventsAreAbsentFromCode() throws {
        let events = try Self.documentedEvents()
        let planned = Set(events.filter { $0.status?.hasPrefix("Planned") == true }.map(\.name))

        // S6 made the last Planned event (`experiment_exposed`) Active, so `planned` may be empty;
        // `everyEventHeadingHasAStatus` is the parser's positive control.
        #expect(planned.isDisjoint(with: Self.codeNames))
    }

    /// Positive control: the parser finds the headings and every one has a recognized status, so an
    /// empty difference above means something.
    @Test func everyEventHeadingHasAStatus() throws {
        let events = try Self.documentedEvents()

        #expect(events.count > 20, "found only \(events.count) event headings")
        let unrecognized = events.filter { event in
            guard let status = event.status else { return true }
            return status.wholeMatch(of: /Active|Planned \(S[0-9]\)/) == nil
        }
        #expect(unrecognized.map(\.name) == [])
    }

    /// Release 1.0 (S7): the taxonomy is final, so every documented event is Active; an event that
    /// isn't implemented is removed from § 3 and recorded as removed in § 4.
    @Test func everyDocumentedEventIsActive() throws {
        let events = try Self.documentedEvents()

        #expect(events.filter { $0.status != "Active" }.map(\.name) == [])
    }

    /// Events recorded as removed in § 4 (rows whose decision starts with `**Removed`) stay out of code.
    @Test func removedEventsStayOutOfCode() throws {
        let root = try #require(RepositoryFiles.root(), "MerchantCatalog.xcodeproj not found above \(#filePath)")
        let removed = Self.removedEvents(in: try RepositoryFiles.text(at: "docs/Analytics.md", root: root))

        #expect(removed.contains("sort_options_opened"), "parser found \(removed)")
        #expect(removed.isDisjoint(with: Self.codeNames))
    }

    /// Table rows ``| `name` | **Removed…`` → `name`.
    private static func removedEvents(in text: String) -> Set<String> {
        var names: Set<String> = []
        for line in text.split(separator: "\n") {
            if let match = line.firstMatch(of: /^\| `([a-z_]+)` \| \*\*Removed/) {
                names.insert(String(match.1))
            }
        }
        return names
    }

    private static func documentedEvents() throws -> [DocumentedEvent] {
        let root = try #require(RepositoryFiles.root(), "MerchantCatalog.xcodeproj not found above \(#filePath)")
        return parse(try RepositoryFiles.text(at: "docs/Analytics.md", root: root))
    }

    /// Each event heading takes the first `- **Status:**` line before the next heading of any level.
    private static func parse(_ text: String) -> [DocumentedEvent] {
        let headingPrefix = "#### `"
        let statusPrefix = "- **Status:** "
        var events: [DocumentedEvent] = []
        var current: Int?

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix(headingPrefix), line.hasSuffix("`") {
                let name = line.dropFirst(headingPrefix.count).dropLast()
                events.append(DocumentedEvent(name: String(name)))
                current = events.count - 1
            } else if line.hasPrefix("#") {
                current = nil
            } else if line.hasPrefix(statusPrefix), let index = current, events[index].status == nil {
                events[index].status = String(line.dropFirst(statusPrefix.count))
            }
        }
        return events
    }
}
