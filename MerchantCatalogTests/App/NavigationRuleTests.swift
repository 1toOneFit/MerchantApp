import Foundation
import Testing

/// Navigation rule (Architecture § 7): `NavigationStack` and `navigationDestination` appear only in
/// `MerchantCatalog/App/AppTabView.swift`; `NavigationLink` and `NavigationView` appear nowhere.
/// Features navigate through view-model intents that call their tab's `Router`.
///
/// A plain source scan: the token is matched anywhere in a file, comments included.
struct NavigationRuleTests {
    private static let navigationOwner = "MerchantCatalog/App/AppTabView.swift"
    private static let forbiddenEverywhere = ["NavigationLink", "NavigationView"]
    private static let ownerOnly = ["NavigationStack", "navigationDestination"]

    @Test func onlyAppTabViewOwnsNavigation() throws {
        let root = try #require(Self.repositoryRoot(), "MerchantCatalog.xcodeproj not found above \(#filePath)")
        let sources = try Self.swiftSources(in: "MerchantCatalog", root: root)
        #expect(!sources.isEmpty, "the scan found no Swift files")

        var offenders: [String] = []
        for (path, text) in sources.sorted(by: { $0.key < $1.key }) {
            let tokens = path == Self.navigationOwner
                ? Self.forbiddenEverywhere
                : Self.forbiddenEverywhere + Self.ownerOnly
            offenders += tokens.filter(text.contains).map { "\(path): \($0)" }
        }
        #expect(offenders == [])

        // Positive control: the scan reads the real owner file, so an empty offender list means something.
        let owner = try #require(sources[Self.navigationOwner], "\(Self.navigationOwner) not found")
        #expect(owner.contains("NavigationStack"))
        #expect(owner.contains("navigationDestination"))
    }

    /// Walks up from this file to the folder that contains `MerchantCatalog.xcodeproj`.
    private static func repositoryRoot(from file: String = #filePath) -> URL? {
        var directory = URL(filePath: file).deletingLastPathComponent()
        while directory.pathComponents.count > 1 {
            let project = directory.appending(path: "MerchantCatalog.xcodeproj")
            if FileManager.default.fileExists(atPath: project.path(percentEncoded: false)) {
                return directory
            }
            directory = directory.deletingLastPathComponent()
        }
        return nil
    }

    /// Contents of every `.swift` file under `folder`, keyed by path relative to `root`.
    private static func swiftSources(in folder: String, root: URL) throws -> [String: String] {
        let enumerator = FileManager.default.enumerator(
            at: root.appending(path: folder),
            includingPropertiesForKeys: nil
        )
        var sources: [String: String] = [:]
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let relative = url.pathComponents.dropFirst(root.pathComponents.count).joined(separator: "/")
            sources[relative] = try String(contentsOf: url, encoding: .utf8)
        }
        return sources
    }
}
