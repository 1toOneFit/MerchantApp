import Foundation
import Synchronization
import UIKit
@testable import MerchantCatalog

/// An `ImageLoading` whose answers the test queues, one per request; the last one repeats.
final class FakeImageLoader: ImageLoading {
    enum Answer: Sendable {
        case image(UIImage)
        case failure(AppError)
        /// Suspends until the calling task is cancelled, then throws `CancellationError`, like
        /// `URLSessionImageLoader` with a request that hasn't answered yet.
        case untilCancelled
        /// Suspends, ignoring cancellation, until `releaseHeld()`; then returns the image. Models a
        /// response that wins the race with a cancellation.
        case held(UIImage)
    }

    private struct State {
        var answers: [Answer]
        var requests: [URL] = []
        var cancellations = 0
        var requestWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
        var held: [CheckedContinuation<Void, Never>] = []
    }

    private let state: Mutex<State>

    init(_ answers: Answer...) {
        state = Mutex(State(answers: answers))
    }

    var requests: [URL] {
        state.withLock { $0.requests }
    }

    /// Requests that ended because their task was cancelled (`.untilCancelled`).
    var cancellations: Int {
        state.withLock { $0.cancellations }
    }

    /// Returns once at least `count` requests have arrived.
    func waitForRequests(_ count: Int = 1) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let ready = state.withLock { state in
                if state.requests.count >= count { return true }
                state.requestWaiters.append((count, continuation))
                return false
            }
            if ready { continuation.resume() }
        }
    }

    /// Lets every `.held` request return.
    func releaseHeld() {
        let held = state.withLock { state in
            let held = state.held
            state.held = []
            return held
        }
        held.forEach { $0.resume() }
    }

    func image(from url: URL) async throws -> UIImage {
        let answer = state.withLock { state in
            state.answers.count > 1 ? state.answers.removeFirst() : state.answers[0]
        }
        switch answer {
        case .image(let image):
            record(url)
            return image
        case .failure(let error):
            record(url)
            throw error
        case .untilCancelled:
            record(url)
            do {
                try await Task.sleep(for: .seconds(3600))
            } catch {
                state.withLock { $0.cancellations += 1 }
            }
            throw CancellationError()
        case .held(let image):
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                state.withLock { $0.held.append(continuation) }
                record(url)
            }
            return image
        }
    }

    private func record(_ url: URL) {
        let ready = state.withLock { state in
            state.requests.append(url)
            let count = state.requests.count
            let ready = state.requestWaiters.filter { $0.count <= count }.map(\.continuation)
            state.requestWaiters.removeAll { $0.count <= count }
            return ready
        }
        ready.forEach { $0.resume() }
    }
}
