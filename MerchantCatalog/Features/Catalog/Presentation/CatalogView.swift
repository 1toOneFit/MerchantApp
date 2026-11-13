import SwiftUI

/// The catalog browse screen: renders `CatalogViewModel.phase` and forwards intents
/// (ProductSpecification § 4.1). It owns its view model; `AppTabView` hosts it in the Catalog tab's
/// navigation stack and passes only whether the Catalog tab is selected.
struct CatalogView: View {
    /// Drives `catalog_viewed` (D-39): true at the first display and on each switch back to the tab.
    /// Popping back from details doesn't change it.
    let isTabSelected: Bool

    @State private var viewModel: CatalogViewModel

    init(viewModel: CatalogViewModel, isTabSelected: Bool) {
        _viewModel = State(initialValue: viewModel)
        self.isTabSelected = isTabSelected
    }

    var body: some View {
        ZStack {
            switch viewModel.phase {
            case .initialLoading:
                CatalogSkeletonGrid()
            case .content(let footer, let refreshError):
                CatalogGrid(viewModel: viewModel, footer: footer, refreshError: refreshError)
            case .empty:
                ContentUnavailableView {
                    Label("No products", systemImage: "shippingbox")
                } description: {
                    Text("The catalog has no products right now.")
                } actions: {
                    Button("Reload") { viewModel.reload() }
                        .buttonStyle(.borderedProminent)
                }
            case .failed(let error):
                ContentUnavailableView {
                    Label("Couldn't load products", systemImage: error == .offline ? "wifi.slash" : "exclamationmark.triangle")
                } description: {
                    Text(error.userMessage)
                } actions: {
                    Button("Retry") { viewModel.retry() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Catalog")
        .task { await viewModel.start() }
        .onChange(of: isTabSelected, initial: true) { _, isSelected in
            if isSelected {
                viewModel.catalogBecameVisible()
            }
        }
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
    let viewModel: CatalogViewModel
    let footer: CatalogFooter
    let refreshError: AppError?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: CatalogLayout.columns, spacing: CatalogLayout.rowSpacing) {
                ForEach(viewModel.cards) { card in
                    ProductCardView(card: card)
                        .onAppear { viewModel.itemAppeared(id: card.id, in: .browse) }
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
