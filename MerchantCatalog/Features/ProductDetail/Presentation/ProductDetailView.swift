import SwiftUI

/// The product details screen (ProductSpecification § 4.3): gallery, header, At a Glance, Pricing,
/// Overview, Product information, Shipping & availability and Recent reviews, top to bottom. It
/// renders at once from the list's product (AC-D1); a section without data is left out (AC-D2). It
/// owns its view model; `AppTabView` pushes it through `ProductDetailConfigurator`.
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
                }
                ProductDetailHeaderView(header: viewModel.header)
                    .padding(.horizontal)
                Group {
                    if !insights.atAGlance.isEmpty {
                        DetailSection("At a Glance") {
                            AtAGlanceView(facts: insights.atAGlance)
                        }
                    }
                    DetailSection("Pricing") {
                        FactRows(facts: insights.pricing)
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
        .onAppear { viewModel.contentAppeared() }
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
