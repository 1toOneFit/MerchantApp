import SwiftUI

/// The save control on cards and in the details toolbar: a bookmark, filled when saved. Its label
/// says what a tap does ("Save" / "Remove from Saved"); the tap target is at least 44 × 44 pt.
struct SaveButton: View {
    let isSaved: Bool
    let action: () -> Void

    var body: some View {
        Button(isSaved ? "Remove from Saved" : "Save", systemImage: isSaved ? "bookmark.fill" : "bookmark", action: action)
            .labelStyle(.iconOnly)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
    }
}

/// The card variant: a small circle on a material, so it reads over any thumbnail.
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
        .accessibilityLabel(isSaved ? "Remove from Saved" : "Save")
    }
}
