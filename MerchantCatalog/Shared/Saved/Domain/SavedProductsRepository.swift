/// Where saved products persist. `SavedProductsStore` depends only on this protocol; `AppContext`
/// registers `FileSavedProductsRepository` under it.
///
/// Neither call throws: the saved list is the merchant's data, and a storage problem must not take
/// the app down. Implementations log failures (`persistence`) and load an empty list.
protocol SavedProductsRepository: Sendable {
    /// The saved products in stored order; empty if there are none or they can't be read.
    func load() async -> [SavedProduct]
    /// Replaces the stored list with `items`.
    func save(_ items: [SavedProduct]) async
}
