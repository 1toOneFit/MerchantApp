import Testing
@testable import MerchantCatalog

/// `AppError` carries the HTTP status for analytics (`http_status`) and a reason-specific message
/// (ProductSpecification § 4.5).
struct AppErrorTests {
    private static let all: [AppError] = [
        .offline, .timeout, .notFound, .rateLimited, .server(status: 503), .decoding, .unknown,
    ]

    @Test(arguments: [
        (AppError.offline, Int?.none),
        (.timeout, nil),
        (.notFound, 404),
        (.rateLimited, 429),
        (.server(status: 503), 503),
        (.decoding, nil),
        (.unknown, nil),
    ])
    func httpStatus(error: AppError, expected: Int?) {
        #expect(error.httpStatus == expected)
    }

    @Test func userMessagesAreDistinct() {
        let messages = Self.all.map(\.userMessage)

        #expect(messages.allSatisfy { !$0.isEmpty })
        #expect(Set(messages).count == Self.all.count)
    }

    @Test func offlineMessageMatchesSpecification() {
        #expect(AppError.offline.userMessage == "You're offline. Check your connection and try again.")
    }
}
