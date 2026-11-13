import Observation

/// The selected tab. `AppTabView` owns it and binds the tab view to it; screens that switch tabs
/// (the Saved empty state's "Browse catalog") get it by injection, like their router (D-61).
@MainActor
@Observable
final class TabSelection {
    /// Bound to the tab view, which also writes it when the user taps a tab.
    var selected: AppTab

    init(selected: AppTab = .catalog) {
        self.selected = selected
    }

    func select(_ tab: AppTab) {
        selected = tab
    }
}
