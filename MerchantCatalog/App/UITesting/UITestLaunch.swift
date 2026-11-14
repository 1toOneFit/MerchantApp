#if DEBUG
import Foundation

/// The launch path of the UI tests (D-88). `MerchantCatalogUITests` launches the app with
/// `-ui-testing`; the app then builds its context with `FixtureProductRepository` instead of the
/// API, a `UserDefaults` suite emptied at each launch (installation, session, experiment and DEBUG
/// settings start fresh) and a new temporary folder for saved products (an empty Saved list that
/// never touches the user's). Everything else (view models, navigation, the saved store, analytics)
/// is the app's own code. DEBUG only: Release builds have no such path.
enum UITestLaunch {
    static let argument = "-ui-testing"

    /// Whether the process was launched by the UI tests.
    static func isRequested(in arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(argument)
    }

    @MainActor
    static func makeContext() -> AppContext {
        let suiteName = "com.example.MerchantCatalog.ui-testing"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("UITestLaunch: no UserDefaults suite \(suiteName)")
        }
        defaults.removePersistentDomain(forName: suiteName)
        let savedProductsDirectory = URL.temporaryDirectory.appending(path: "ui-testing-\(UUID().uuidString)", directoryHint: .isDirectory)
        return AppContext.configure(
            defaults: defaults,
            savedProductsDirectory: savedProductsDirectory,
            productRepository: FixtureProductRepository()
        )
    }
}
#endif
