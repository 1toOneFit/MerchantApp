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
        let root = try #require(RepositoryFiles.root(), "MerchantCatalog.xcodeproj not found above \(#filePath)")
        let sources = try RepositoryFiles.swiftSources(in: "MerchantCatalog", root: root)
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
}
