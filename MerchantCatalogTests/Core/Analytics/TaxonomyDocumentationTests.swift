import Foundation
import Testing
@testable import MerchantCatalog

/// `docs/Analytics.md` is the authoritative taxonomy. Every event there is a level-4 heading
/// ``#### `event_name` `` followed by a `- **Status:**` line. Active events must equal
/// `AnalyticsEventName` in code; Planned events must not exist in code yet.
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
