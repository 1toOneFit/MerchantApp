import SwiftUI

/// The Saved tab (ProductSpecification § 4.4): saved products, most recent first, labeled as saved
/// information; swipe to remove; an empty state with Browse catalog. It needs no network: rows are
/// the snapshots (thumbnails load only when online). It owns its view model; `AppTabView` hosts it in
/// the Saved tab's navigation stack.
struct SavedView: View {
    /// Drives `saved_products_viewed` (D-39): true on each switch to the tab.
    let isTabSelected: Bool

    @State private var viewModel: SavedViewModel

    init(viewModel: SavedViewModel, isTabSelected: Bool) {
        _viewModel = State(initialValue: viewModel)
        self.isTabSelected = isTabSelected
    }

    var body: some View {
        content
            .navigationTitle("Saved")
            .onChange(of: isTabSelected, initial: true) { _, isSelected in
                if isSelected {
                    viewModel.savedBecameVisible()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            Color.clear
        case .empty:
            ContentUnavailableView {
                Label("No saved products", systemImage: "bookmark")
            } description: {
                Text("Save products from the catalog to keep a shortlist. Saved products stay available offline.")
            } actions: {
                Button("Browse catalog") { viewModel.browseCatalogTapped() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        case .content:
            List {
                ForEach(viewModel.rows) { row in
                    Button {
                        viewModel.rowSelected(id: row.id)
                    } label: {
                        SavedRowView(row: row)
                    }
                    .foregroundStyle(.primary)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Remove", systemImage: "trash", role: .destructive) {
                            viewModel.removeSwiped(id: row.id)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

/// Thumbnail, title, price when saved and saved date; VoiceOver reads it as one element.
private struct SavedRowView: View {
    let row: SavedRowModel

    var body: some View {
        HStack(spacing: 12) {
            ProductImageView(url: row.thumbnailURL)
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.subheadline)
                    .lineLimit(2)
                Text(row.priceWhenSaved)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(row.savedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
