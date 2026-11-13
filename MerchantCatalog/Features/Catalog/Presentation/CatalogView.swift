import SwiftUI

/// The catalog screen: the browse grid, the search field and the sort menu (ProductSpecification
/// § 4.1, § 4.2). It renders the view model's lists and forwards intents. It owns its view model;
/// `AppTabView` hosts it in the Catalog tab's navigation stack and passes only whether the Catalog
/// tab is selected.
///
/// While a search is shown, the browse list stays in the hierarchy underneath, invisible and inert,
/// so clearing the search shows it at the same scroll position with its thumbnails loaded (D-47).
struct CatalogView: View {
    /// Drives `catalog_viewed` (D-39): true at the first display and on each switch back to the tab.
    /// Popping back from details doesn't change it.
    let isTabSelected: Bool

    @State private var viewModel: CatalogViewModel
    @State private var isSearchPresented = false

    init(viewModel: CatalogViewModel, isTabSelected: Bool) {
        _viewModel = State(initialValue: viewModel)
        self.isTabSelected = isTabSelected
    }

    var body: some View {
        let isShowingSearch = viewModel.searchList != nil
        ZStack {
            CatalogListView(content: viewModel.browseList, context: .browse, viewModel: viewModel, clearSearch: clearSearch)
                .opacity(isShowingSearch ? 0 : 1)
                .allowsHitTesting(!isShowingSearch)
                .accessibilityHidden(isShowingSearch)
            if let searchList = viewModel.searchList {
                CatalogListView(content: searchList, context: .search, viewModel: viewModel, clearSearch: clearSearch)
            }
        }
        .navigationTitle("Catalog")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: searchText,
            isPresented: $isSearchPresented,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search products"
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CatalogSortMenu(sort: viewModel.sort) { viewModel.sortSelected($0) }
            }
        }
        .task { await viewModel.start() }
        .onChange(of: isTabSelected, initial: true) { _, isSelected in
            if isSelected {
                viewModel.catalogBecameVisible()
            }
        }
    }

    /// The field shows the text as typed; the view model decides what to search (D-49, D-50).
    private var searchText: Binding<String> {
        Binding(
            get: { viewModel.searchText },
            set: { viewModel.searchTextChanged(to: $0) }
        )
    }

    /// The no-results state's Clear search: back to browse, and the search field is dismissed.
    private func clearSearch() {
        viewModel.clearSearch()
        isSearchPresented = false
    }
}

/// One list (browse, or search results) in its current phase.
private struct CatalogListView: View {
    let content: CatalogListContent
    let context: ListContext
    let viewModel: CatalogViewModel
    let clearSearch: () -> Void

    var body: some View {
        switch content.phase {
        case .initialLoading:
            CatalogSkeletonGrid()
        case .content(let footer, let refreshError):
            // A new list (sort change, new query, Retry, Reload) gets a new grid, and a new scroll
            // view starts at the top. A page 1 shows the skeleton in between, which replaces the
            // grid too; the identity makes the reset independent of that frame being drawn.
            CatalogGrid(cards: content.cards, context: context, footer: footer, refreshError: refreshError, viewModel: viewModel)
                .id(content.listID)
        case .empty:
            ContentUnavailableView {
                Label("No products", systemImage: "shippingbox")
            } description: {
                Text("The catalog has no products right now.")
            } actions: {
                Button("Reload") { viewModel.reload() }
                    .buttonStyle(.borderedProminent)
            }
        case .noResults(let query):
            ContentUnavailableView {
                Label("No results", systemImage: "magnifyingglass")
            } description: {
                Text(CatalogCopy.noResultsMessage(for: query))
            } actions: {
                Button("Clear search", action: clearSearch)
                    .buttonStyle(.borderedProminent)
            }
        case .failed(let error):
            ContentUnavailableView {
                Label(
                    context == .search ? "Couldn't search products" : "Couldn't load products",
                    systemImage: error == .offline ? "wifi.slash" : "exclamationmark.triangle"
                )
            } description: {
                Text(error.userMessage)
            } actions: {
                Button("Retry") { viewModel.retry() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

/// The toolbar's sort control: its label always shows the current sort; the menu marks it with a
/// checkmark (ProductSpecification § 4.2, D-44).
private struct CatalogSortMenu: View {
    let sort: ProductSort
    let select: (ProductSort) -> Void

    var body: some View {
        Menu {
            Picker("Sort", selection: Binding(get: { sort }, set: { select($0) })) {
                ForEach(ProductSort.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            Label(sort.shortTitle, systemImage: "arrow.up.arrow.down")
                .labelStyle(.titleAndIcon)
        }
        .accessibilityLabel("Sort")
        .accessibilityValue(sort.title)
    }
}

/// Two flexible columns (ProductSpecification § 2).
private enum CatalogLayout {
    static let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
    ]
    static let rowSpacing: CGFloat = 20
}

private struct CatalogGrid: View {
    let cards: [ProductCardModel]
    let context: ListContext
    let footer: CatalogFooter
    let refreshError: AppError?
    let viewModel: CatalogViewModel

    var body: some View {
        ScrollView {
            LazyVGrid(columns: CatalogLayout.columns, spacing: CatalogLayout.rowSpacing) {
                ForEach(cards) { card in
                    ProductCardView(card: card)
                        .onAppear { viewModel.itemAppeared(id: card.id, in: context) }
                }
            }
            .padding(.horizontal)

            CatalogFooterView(footer: footer) { viewModel.retryPage() }
                .padding()
        }
        .refreshable { await viewModel.refresh() }
        .safeAreaInset(edge: .top) {
            if let refreshError {
                ErrorBanner(message: refreshError.userMessage) { viewModel.dismissRefreshError() }
            }
        }
    }
}

/// The row under the grid: nothing, a spinner, a page error with Retry, or the end of the list.
private struct CatalogFooterView: View {
    let footer: CatalogFooter
    let retry: () -> Void

    var body: some View {
        switch footer {
        case .idle:
            Color.clear
                .frame(height: 1)
        case .loading:
            ProgressView()
                .accessibilityLabel("Loading more products")
        case .failed(let error):
            VStack {
                Text(error.userMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry", action: retry)
                    .buttonStyle(.bordered)
            }
        case .end:
            Text("You've reached the end")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// Redacted placeholder cards while the first page loads.
private struct CatalogSkeletonGrid: View {
    private let cards = (0..<8).map(ProductCardModel.placeholder)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: CatalogLayout.columns, spacing: CatalogLayout.rowSpacing) {
                ForEach(cards) { card in
                    ProductCardView(card: card)
                }
            }
            .padding(.horizontal)
        }
        .scrollDisabled(true)
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading products")
    }
}
