import Testing
@testable import MerchantCatalog

/// The selected tab, owned by `AppTabView` and injected into screens that switch tabs (D-61).
@MainActor
struct TabSelectionTests {
    @Test func startsOnCatalog() {
        #expect(TabSelection().selected == .catalog)
    }

    @Test func selectSwitchesTab() {
        let tabs = TabSelection()

        tabs.select(.saved)
        #expect(tabs.selected == .saved)

        tabs.select(.catalog)
        #expect(tabs.selected == .catalog)
    }
}
