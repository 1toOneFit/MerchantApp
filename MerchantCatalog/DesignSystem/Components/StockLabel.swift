import SwiftUI

/// How a stock count reads on cards and details (D-84, D-86): "Out of stock", "Low stock · 7 left",
/// "In stock". How many are left is said only when stock is low; details list the exact count in
/// Shipping & availability.
struct StockLabel: Hashable, Sendable {
    let status: StockStatus
    let text: String
    /// What VoiceOver reads: the same words, with a comma for the separator.
    let accessibilityText: String

    /// `nil` when the stock is unknown: no status is shown (D-84).
    init?(stock: Int?) {
        guard let stock, let status = StockStatus(stock: stock) else { return nil }
        self.status = status
        switch status {
        case .outOfStock:
            text = "Out of stock"
            accessibilityText = text
        case .lowStock:
            text = "Low stock · \(stock) left"
            accessibilityText = "Low stock, \(stock) left"
        case .inStock:
            text = "In stock"
            accessibilityText = text
        }
    }
}

/// A stock label with its status symbol and color: a compact row on cards, a capsule badge on
/// details. Only system colors, so it follows dark mode. VoiceOver reads `accessibilityText`.
struct StockStatusView: View {
    enum Style {
        /// One line under a card's price.
        case row
        /// The details header's prominent capsule.
        case badge
    }

    let label: StockLabel
    var style: Style = .row

    var body: some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label.accessibilityText)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .row:
            Label {
                Text(label.text)
                    .foregroundStyle(label.status == .inStock ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint))
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
            }
            .font(.caption.weight(.medium))
            .lineLimit(1)
        case .badge:
            Label(label.text, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(tint.opacity(0.15), in: .capsule)
        }
    }

    private var symbol: String {
        switch label.status {
        case .outOfStock: "xmark.circle.fill"
        case .lowStock: "exclamationmark.triangle.fill"
        case .inStock: "checkmark.circle.fill"
        }
    }

    private var tint: Color {
        switch label.status {
        case .outOfStock: .red
        case .lowStock: .orange
        case .inStock: .green
        }
    }
}
