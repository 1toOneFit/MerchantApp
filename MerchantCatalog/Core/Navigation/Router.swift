import Observation

/// Owns one tab's navigation path. `AppTabView` creates one router per tab and binds `path` to that
/// tab's navigation stack. Features navigate through view-model intents that call the router.
@MainActor
@Observable
final class Router {
    /// Bound to the tab's navigation stack, which also writes it when the user goes back.
    var path: [Route]

    init(path: [Route] = []) {
        self.path = path
    }

    func push(_ route: Route) {
        path.append(route)
        let depth = path.count
        Log.navigation.debug("push \(route.logDescription, privacy: .public), depth \(depth, privacy: .public)")
    }

    /// Opens product details on this tab's stack.
    func showProductDetail(_ route: ProductDetailRoute) {
        push(.productDetail(route))
    }

    /// Removes the top route; does nothing at the root.
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
        let depth = path.count
        Log.navigation.debug("pop, depth \(depth, privacy: .public)")
    }

    /// Returns to the tab's root; does nothing at the root.
    func popToRoot() {
        guard !path.isEmpty else { return }
        path.removeAll()
        Log.navigation.debug("pop to root")
    }
}
