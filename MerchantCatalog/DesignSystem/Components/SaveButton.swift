import SwiftUI

/// The save control in the details toolbar: a bookmark, filled when saved. Its label says what a tap
/// does ("Save" / "Remove from Saved"); the tap target is at least 44 × 44 pt.
struct SaveButton: View {
    let isSaved: Bool
    let action: () -> Void

    /// What a tap does: "Save" or "Remove from Saved". Also the card's VoiceOver action name.
    nonisolated static func title(isSaved: Bool) -> String {
        isSaved ? "Remove from Saved" : "Save"
    }

    var body: some View {
        Button(SaveButton.title(isSaved: isSaved), systemImage: isSaved ? "bookmark.fill" : "bookmark", action: action)
            .labelStyle(.iconOnly)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
    }
}

/// The card variant: a small circle on a material, so it reads over any thumbnail, inside a 44 × 44 pt
/// tap target. In the grid VoiceOver doesn't focus it: the card element carries a save action
/// instead (`CatalogView`).
struct CardSaveButton: View {
    let isSaved: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)
                .background(.regularMaterial, in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(SaveButton.title(isSaved: isSaved))
    }
}
