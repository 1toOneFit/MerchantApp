import SwiftUI

/// The product details screen (ProductSpecification § 4.3): gallery, header, At a Glance, Pricing,
/// Overview, Product information, Shipping & availability and Recent reviews, top to bottom. The
/// header shows at once from the list item's summary or the saved snapshot, with a gallery skeleton,
/// while `/products/{id}` loads the full product (AC-D1, D-81; § 4.4, AC-D4); a section without data is left out (AC-D2). The toolbar's save
/// button follows the shared store (AC-D3). It owns its view model; `AppTabView` pushes it through
/// `ProductDetailConfigurator`.
struct ProductDetailView: View {
    @State private var viewModel: ProductDetailViewModel

    init(viewModel: ProductDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        let insights = viewModel.insights
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !viewModel.gallery.imageURLs.isEmpty {
                    ProductGalleryView(gallery: viewModel.gallery, selection: gallerySelection)
                } else if viewModel.showsGallerySkeleton {
                    GallerySkeleton()
                }
                ProductDetailHeaderView(header: viewModel.header)
                    .padding(.horizontal)
                DetailStatusView(
                    snapshot: viewModel.isShowingSnapshot ? viewModel.savedSnapshot : nil,
                    refresh: viewModel.refresh,
                    message: viewModel.statusMessage
                ) {
                    viewModel.retry()
                }
                .padding(.horizontal)
                Group {
                    if !insights.atAGlance.isEmpty {
                        DetailSection("At a Glance") {
                            AtAGlanceView(facts: insights.atAGlance)
                        }
                    }
                    DetailSection("Pricing") {
                        FactRows(facts: insights.pricing)
                        if let savedPrice = viewModel.savedPriceIfChanged {
                            PriceChangedNote(savedPrice: savedPrice)
                        }
                    }
                    if !insights.overview.isEmpty {
                        DetailSection("Overview") {
                            OverviewView(facts: insights.overview)
                        }
                    }
                    if !insights.productInformation.isEmpty {
                        DetailSection("Product information") {
                            FactRows(facts: insights.productInformation)
                        }
                    }
                    if !insights.shippingAndAvailability.isEmpty {
                        DetailSection("Shipping & availability") {
                            FactRows(facts: insights.shippingAndAvailability)
                        }
                    }
                    if !insights.reviews.isEmpty {
                        DetailSection("Recent reviews") {
                            ReviewsView(reviews: insights.reviews)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SaveButton(isSaved: viewModel.isSaved) { viewModel.saveToggled() }
            }
        }
        .onAppear { viewModel.contentAppeared() }
        .task { await viewModel.start() }
    }

    /// The gallery reports page changes to the view model, which keeps the index (D-59).
    private var gallerySelection: Binding<Int> {
        Binding(
            get: { viewModel.galleryIndex },
            set: { viewModel.galleryPageChanged(to: $0) }
        )
    }
}

private struct ProductDetailHeaderView: View {
    let header: ProductDetailHeader

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(header.title)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            if let brand = header.brand {
                Text(brand)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            if let category = header.category {
                Text(category)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Under the header until the full product shows (D-81): from Saved, the snapshot labeled as saved
/// information; then the request's state: in progress, failed with Retry, or the product gone
/// (ProductSpecification § 4.3). The wording comes from the view model.
private struct DetailStatusView: View {
    /// The snapshot while it is what the screen shows; `nil` from a list or once refreshed.
    let snapshot: SavedProduct?
    let refresh: DetailRefreshState
    let message: String?
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let snapshot {
                Text("Saved information · \(SavedProductFormat.savedDate(snapshot.savedAt))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            switch refresh {
            case .idle, .refreshed:
                EmptyView()
            case .loading:
                // From a list the gallery skeleton shows the loading; Saved adds "Updating…".
                if let message {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            case .failed:
                StatusBanner(systemImage: "exclamationmark.triangle.fill", message: message ?? "") {
                    Button("Retry", action: retry)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            case .unavailable:
                StatusBanner(systemImage: "xmark.circle.fill", message: message ?? "") {
                    EmptyView()
                }
            }
        }
    }
}

/// Where the gallery will be while the full product loads: the image placeholder's fill at the
/// gallery's square size, so the images replace it without moving the content below. A spinner and
/// a slow pulse show that it is loading; with Reduce Motion the pulse is off and the spinner stays.
private struct GallerySkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDimmed = false

    var body: some View {
        Rectangle()
            .fill(.fill.tertiary)
            .opacity(isDimmed ? 0.4 : 1)
            .overlay {
                ProgressView()
                    .controlSize(.large)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    isDimmed = true
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Loading product images")
    }
}

/// A message on a material background with an optional action.
private struct StatusBanner<Action: View>: View {
    let systemImage: String
    let message: String
    @ViewBuilder let action: Action

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(message)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
            action
        }
        .padding(12)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }
}

/// The fresh price differs from the snapshot's: said factually, with the price when saved.
private struct PriceChangedNote: View {
    let savedPrice: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Price changed since you saved it", systemImage: "info.circle")
                .font(.subheadline.weight(.medium))
            Text(SavedProductFormat.priceWhenSaved(savedPrice))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A titled block; the title is a VoiceOver heading.
private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            content
        }
    }
}

/// Compact chips, as many per row as fit.
private struct AtAGlanceView: View {
    let facts: [ProductInsights.Fact]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8, alignment: .top)], alignment: .leading, spacing: 8) {
            ForEach(facts, id: \.self) { fact in
                let row = ProductFactRow(fact)
                VStack(alignment: .leading, spacing: 2) {
                    Label(row.label, systemImage: row.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(row.value)
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.fill.quaternary, in: .rect(cornerRadius: 10))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// One labeled row per fact.
private struct FactRows: View {
    let facts: [ProductInsights.Fact]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(facts, id: \.self) { fact in
                let row = ProductFactRow(fact)
                LabeledContent {
                    Text(row.value)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label(row.label, systemImage: row.systemImage)
                }
                .font(.subheadline)
            }
        }
    }
}

/// The description as text, then the tags.
private struct OverviewView: View {
    let facts: [ProductInsights.Fact]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(facts, id: \.self) { fact in
                if case .description(let description) = fact {
                    Text(description)
                        .font(.body)
                } else {
                    FactRows(facts: [fact])
                }
            }
        }
    }
}

/// The few reviews the API returns: rating, comment, reviewer name and date. Never the email.
private struct ReviewsView: View {
    let reviews: [ProductReview]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(reviews, id: \.self) { review in
                VStack(alignment: .leading, spacing: 4) {
                    if let rating = review.rating {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Rated \(rating) of 5")
                    }
                    if let comment = review.comment {
                        Text(comment)
                            .font(.subheadline)
                    }
                    let byline = [review.reviewerName, review.date?.formatted(date: .abbreviated, time: .omitted)].compactMap(\.self)
                    if !byline.isEmpty {
                        Text(byline.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
