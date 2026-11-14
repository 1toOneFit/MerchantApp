import SwiftUI

/// The catalog screen: the browse grid, the search field, the sort menu and the All products /
/// Needs attention scope (ProductSpecification § 4.1, § 4.2, § 4.6). It renders the view model's
/// lists and forwards intents. It owns its view model; `AppTabView` hosts it in the Catalog tab's
/// navigation stack and passes only whether the Catalog tab is selected.
///
/// While a search is shown, the browse list stays in the hierarchy underneath, invisible and inert,
/// so clearing the search shows it at the same scroll position with its thumbnails loaded (D-47).
/// A card tap asks the view model to open details on the Catalog tab's stack (D-53); this view stays
/// underneath, so going back shows it as it was (AC-C6). The card's save button toggles the shared
/// saved store (D-60).
struct CatalogView: View {
    /// Drives `catalog_viewed` (D-39): true at the first display and on each switch back to the tab.
    /// Popping back from details doesn't change it.
    let isTabSelected: Bool

    @State private var viewModel: CatalogViewModel
    @State private var isSearchPresented = false
    /// The search field's keyboard focus, separate from `isSearchPresented`: dropping focus puts the
    /// keyboard away and keeps the search (query, results, sort); only Cancel ends it (D-79).
    @FocusState private var isSearchFocused: Bool

    init(viewModel: CatalogViewModel, isTabSelected: Bool) {
        _viewModel = State(initialValue: viewModel)
        self.isTabSelected = isTabSelected
    }

    var body: some View {
        let isShowingSearch = viewModel.searchList != nil
        ZStack {
            // Hidden from VoiceOver inside `CatalogListView`, not here: an `accessibilityHidden(false)`
            // around the list would override the hidden scope grid's `true` inside it (D-90).
            CatalogListView(content: viewModel.browseList, context: .browse, isHidden: isShowingSearch, viewModel: viewModel, clearSearch: clearSearch, dismissKeyboard: dismissKeyboard)
                .opacity(isShowingSearch ? 0 : 1)
                .allowsHitTesting(!isShowingSearch)
            if let searchList = viewModel.searchList {
                CatalogListView(content: searchList, context: .search, isHidden: false, viewModel: viewModel, clearSearch: clearSearch, dismissKeyboard: dismissKeyboard)
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
        .searchFocused($isSearchFocused)
        // The keyboard's Search key puts the keyboard away; the debounce still decides when to search.
        .onSubmit(of: .search) { dismissKeyboard() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CatalogSortMenu(sort: viewModel.sort) { viewModel.sortSelected($0) }
            }
        }
        .onChange(of: isSearchPresented) { wasPresented, isPresented in
            // Cancel ends the search explicitly, without relying on the system emptying the text.
            if wasPresented, !isPresented {
                viewModel.searchDismissed()
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
    /// Puts the search keyboard away, animated, without ending the search (D-79): only the field's
    /// focus changes, never `isSearchPresented`. Called by the Search key and when the user starts
    /// scrolling a grid.
    private func dismissKeyboard() {
        guard isSearchFocused else { return }
        withAnimation {
            isSearchFocused = false
        }
    }

    private func clearSearch() {
        viewModel.clearSearch()
        isSearchPresented = false
    }
}

/// One list (browse, or search results) in its current phase. `isHidden`: the browse list under
/// search results (D-47), hidden from VoiceOver. Each branch sets `accessibilityHidden` itself, never
/// a wrapper around them all: SwiftUI lets an outer `accessibilityHidden(false)` override an inner
/// `true`, which would expose the hidden scope grid (D-90; seen in the UI tests).
private struct CatalogListView: View {
    let content: CatalogListContent
    let context: ListContext
    let isHidden: Bool
    let viewModel: CatalogViewModel
    let clearSearch: () -> Void
    let dismissKeyboard: () -> Void

    var body: some View {
        switch content.phase {
        case .initialLoading:
            CatalogSkeletonGrid()
                .accessibilityHidden(isHidden)
        case .content(let footer, let refreshError):
            // A new list (sort change, new query, Retry, Reload) gets new grids, and a new scroll
            // view starts at the top. A page 1 shows the skeleton in between, which replaces the
            // grids too; the identity makes the reset independent of that frame being drawn.
            CatalogScopedGrids(content: content, context: context, isLayerHidden: isHidden, footer: footer, refreshError: refreshError, viewModel: viewModel, dismissKeyboard: dismissKeyboard)
                .id(content.listID)
                // Pinned over the grids: the cards scroll under it, it never scrolls away (D-90).
                .safeAreaBar(edge: .top) {
                    CatalogScopeBar(scope: content.scope, attentionCount: content.attentionCount) { viewModel.scopeSelected($0) }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .accessibilityHidden(isHidden)
                }
        case .empty:
            ContentUnavailableView {
                Label("No products", systemImage: "shippingbox")
            } description: {
                Text("The catalog has no products right now.")
            } actions: {
                Button("Reload") { viewModel.reload() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .accessibilityHidden(isHidden)
        case .noResults(let query):
            ContentUnavailableView {
                Label("No results", systemImage: "magnifyingglass")
            } description: {
                Text(CatalogCopy.noResultsMessage(for: query))
            } actions: {
                Button("Clear search", action: clearSearch)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .accessibilityHidden(isHidden)
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
                    .controlSize(.large)
            }
            .accessibilityHidden(isHidden)
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

/// One grid per scope, both kept while the list lives, so All products and Needs attention each
/// keep their own scroll position when the user switches between them (D-90). The grid of the other
/// scope stays in the hierarchy invisible, inert and hidden from VoiceOver, like the browse list
/// under search results (D-47). The Needs attention grid is built the first time it is selected, so
/// it loads no thumbnails before then.
private struct CatalogScopedGrids: View {
    let content: CatalogListContent
    let context: ListContext
    /// The whole list is under search results (D-47).
    let isLayerHidden: Bool
    let footer: CatalogFooter
    let refreshError: AppError?
    let viewModel: CatalogViewModel
    let dismissKeyboard: () -> Void

    @State private var hasShownAttention = false

    var body: some View {
        ZStack {
            grid(for: .all)
            if hasShownAttention || content.scope == .needsAttention {
                grid(for: .needsAttention)
            }
        }
        .onChange(of: content.scope, initial: true) { _, scope in
            if scope == .needsAttention {
                hasShownAttention = true
            }
        }
    }

    private func grid(for scope: CatalogScope) -> some View {
        let isActive = scope == content.scope
        return CatalogGrid(
            cards: content.cards(in: scope),
            scope: scope,
            isActive: isActive,
            context: context,
            footer: footer,
            refreshError: refreshError,
            coverage: content.coverage,
            viewModel: viewModel,
            dismissKeyboard: dismissKeyboard
        )
        .opacity(isActive ? 1 : 0)
        .allowsHitTesting(isActive)
        .accessibilityHidden(isLayerHidden || !isActive)
    }
}

/// The cards of one scope and the footer. In Needs attention the footer says how many products the
/// count has checked and checks more on request (D-85). Only the grid on screen (`isActive`) reports
/// card appearances, so a hidden grid neither pages nor counts as an experiment exposure.
private struct CatalogGrid: View {
    let cards: [ProductCardModel]
    let scope: CatalogScope
    let isActive: Bool
    let context: ListContext
    let footer: CatalogFooter
    let refreshError: AppError?
    let coverage: AttentionCoverage
    let viewModel: CatalogViewModel
    let dismissKeyboard: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            if scope == .needsAttention, cards.isEmpty {
                NoAttentionView()
            }
            LazyVGrid(columns: CatalogLayout.columns(for: dynamicTypeSize), spacing: CatalogLayout.rowSpacing) {
                ForEach(cards) { card in
                    let isSaved = viewModel.isSaved(card.id)
                    // The save button is a sibling over the thumbnail's corner, not nested in the
                    // card's button, so each takes its own taps (D-60). VoiceOver reads the pair as
                    // one element that opens details, with a custom action to save or unsave
                    // (ProductSpecification § 4.5).
                    ZStack(alignment: .topTrailing) {
                        Button {
                            viewModel.cardSelected(id: card.id, in: context)
                        } label: {
                            ProductCardView(card: card)
                        }
                        .buttonStyle(.plain)
                        CardSaveButton(isSaved: isSaved) {
                            viewModel.saveToggled(id: card.id, in: context)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(ProductCardAccessibility.label(title: card.title, price: card.price, stock: card.stock?.accessibilityText, rating: card.rating, isSaved: isSaved))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("catalog.productCard.\(card.id)")
                    .accessibilityAction {
                        viewModel.cardSelected(id: card.id, in: context)
                    }
                    .accessibilityAction(named: ProductCardAccessibility.saveActionName(isSaved: isSaved)) {
                        viewModel.saveToggled(id: card.id, in: context)
                    }
                    .onAppear {
                        if isActive {
                            viewModel.itemAppeared(id: card.id, in: context)
                        }
                    }
                }
            }
            .padding(.horizontal)

            if scope == .needsAttention {
                AttentionFooterView(footer: footer, coverage: coverage, loadMore: viewModel.loadMoreTapped, retry: viewModel.retryPage)
                    .padding()
            } else {
                CatalogFooterView(footer: footer) { viewModel.retryPage() }
                    .padding()
            }
        }
        // Starting to scroll (a finger drag, either direction) puts the search keyboard away,
        // animated; the search stays (D-79). The system's own dismissal is off so this is the only
        // path (the developer saw `.immediately` hide it without animation).
        .scrollDismissesKeyboard(.never)
        .onScrollPhaseChange { _, newPhase in
            if newPhase == .interacting {
                dismissKeyboard()
            }
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
                    .controlSize(.large)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            LazyVGrid(columns: CatalogLayout.columns(for: dynamicTypeSize), spacing: CatalogLayout.rowSpacing) {
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
