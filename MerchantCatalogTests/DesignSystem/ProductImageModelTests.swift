import Foundation
import Testing
import UIKit
@testable import MerchantCatalog

/// `ProductImageView`'s state (Networking.md § 4, D-78): it loads while the view is on screen
/// (`.task(id: url)`), and a disappearance cancels an in-flight load and releases the image, so the
/// placeholder shows and nothing lands late.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ProductImageModelTests {
    private static let first = URL(string: "https://cdn.example/1.webp")!
    private static let second = URL(string: "https://cdn.example/2.webp")!
    private static let image = UIImage(systemName: "star")!
    private static let otherImage = UIImage(systemName: "heart")!

    @Test func loadsTheImage() async {
        let loader = FakeImageLoader(.image(Self.image))
        let model = ProductImageModel()

        await model.load(Self.first, using: loader)

        #expect(model.phase == .loaded(Self.image))
        #expect(loader.requests == [Self.first])
    }

    @Test func noURLRequestsNothing() async {
        let loader = FakeImageLoader(.image(Self.image))
        let model = ProductImageModel()

        await model.load(nil, using: loader)

        #expect(model.phase == .empty)
        #expect(loader.requests == [])
    }

    @Test func failureShowsTheFailureState() async {
        let loader = FakeImageLoader(.failure(.offline))
        let model = ProductImageModel()

        await model.load(Self.first, using: loader)

        #expect(model.phase == .failed)
    }

    /// Fast scrolling: the cell disappears while its image is still loading. SwiftUI cancels the
    /// view's `.task`; the cancellation reaches the loader and the placeholder stays.
    @Test func cancellingTheTaskCancelsTheLoad() async {
        let loader = FakeImageLoader(.untilCancelled)
        let model = ProductImageModel()
        let task = Task { await model.load(Self.first, using: loader) }

        await loader.waitForRequests()
        task.cancel()
        await task.value

        #expect(loader.cancellations == 1)
        #expect(model.phase == .empty)
    }

    /// A response that wins the race with the cancellation is dropped.
    @Test func lateImageAfterCancellationIsIgnored() async {
        let loader = FakeImageLoader(.held(Self.image))
        let model = ProductImageModel()
        let task = Task { await model.load(Self.first, using: loader) }

        await loader.waitForRequests()
        task.cancel()
        loader.releaseHeld()
        await task.value

        #expect(model.phase == .empty)
    }

    /// A failure that arrives after the cancellation doesn't show the failure icon either: the next
    /// appearance loads again from the placeholder.
    @Test func lateFailureAfterCancellationIsIgnored() async {
        let loader = FakeImageLoader(.failure(.timeout))
        let model = ProductImageModel()
        let task = Task { await model.load(Self.first, using: loader) }

        task.cancel()
        await task.value

        #expect(model.phase == .empty)
    }

    /// The view resets on disappear: the decoded image is released, as `AsyncImage` released it
    /// when it was removed (no in-memory cache, D-10).
    @Test func resetReleasesTheImage() async {
        let loader = FakeImageLoader(.image(Self.image))
        let model = ProductImageModel()
        await model.load(Self.first, using: loader)

        model.reset()

        #expect(model.phase == .empty)
    }

    /// A new URL (cell reuse with another product) never shows the previous product's image while
    /// the new one loads.
    @Test func newURLClearsThePreviousImageWhileLoading() async {
        let loader = FakeImageLoader(.image(Self.image), .held(Self.otherImage))
        let model = ProductImageModel()
        await model.load(Self.first, using: loader)

        let task = Task { await model.load(Self.second, using: loader) }
        await loader.waitForRequests(2)
        #expect(model.phase == .empty)

        loader.releaseHeld()
        await task.value
        #expect(model.phase == .loaded(Self.otherImage))
        #expect(loader.requests == [Self.first, Self.second])
    }
}
