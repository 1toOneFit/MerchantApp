import SwiftUI

/// "All products" | "Needs attention" with its count, pinned at the top of the list on screen (D-85,
/// D-90). The count is the loaded products that are low or out of stock. Two chips side by side,
/// stacked when they don't fit (large text). Each is at least 44 pt tall (D-76) and has a stable
/// identifier for UI tests.
struct CatalogScopeBar: View {
    let scope: CatalogScope
    let attentionCount: Int
    let select: (CatalogScope) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips }
            VStack(alignment: .leading, spacing: 8) { chips }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var chips: some View {
        ScopeChip(title: "All products", systemImage: nil, count: nil, isSelected: scope == .all) {
            select(.all)
        }
        .accessibilityIdentifier("catalog.allProducts")
        ScopeChip(title: "Needs attention", systemImage: "exclamationmark.triangle.fill", count: attentionCount, isSelected: scope == .needsAttention) {
            select(.needsAttention)
        }
        .accessibilityIdentifier("catalog.needsAttention")
    }
}

/// One capsule of the scope bar: filled with the tint when selected.
private struct ScopeChip: View {
    let title: String
    let systemImage: String?
    let count: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.orange))
                }
                Text(title)
                if let count {
                    Text(count, format: .number)
                        .monospacedDigit()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(isSelected ? AnyShapeStyle(.white.opacity(0.25)) : AnyShapeStyle(.fill.secondary), in: .capsule)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(count.map { $0 == 1 ? "1 product" : "\($0) products" } ?? "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Needs attention with nothing to show among the loaded products.
struct NoAttentionView: View {
    var body: some View {
        ContentUnavailableView(
            "Nothing needs attention",
            systemImage: "checkmark.circle",
            description: Text("None of the checked products is low or out of stock.")
        )
        .accessibilityIdentifier("catalog.noAttention")
    }
}

/// The row under the Needs attention grid: how many products the count has checked ("Checked 120 of
/// 194 products."), and the way to check more. Pages don't load as cards appear in this scope
/// (D-85), so more products load only from "Check 20 more products"; a failed page keeps its Retry.
struct AttentionFooterView: View {
    let footer: CatalogFooter
    let coverage: AttentionCoverage
    let loadMore: () -> Void
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(CatalogCopy.attentionCoverage(coverage))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("catalog.attentionCoverage")
            switch footer {
            case .idle:
                Button(CatalogCopy.checkMoreButton(coverage, pageSize: CatalogViewModel.pageSize), action: loadMore)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("catalog.loadMore")
            case .loading:
                ProgressView()
                    .accessibilityLabel("Loading more products")
            case .failed(let error):
                Text(error.userMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry", action: retry)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            case .end:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
    }
}
