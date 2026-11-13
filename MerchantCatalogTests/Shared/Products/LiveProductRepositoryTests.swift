import Foundation
import Testing
@testable import MerchantCatalog

/// `LiveProductRepository` builds the list target and maps the response; it depends only on
/// `APIClientType` (Architecture § 4).
@MainActor
struct LiveProductRepositoryTests {
    @Test func requestsListTargetAndMapsPage() async throws {
        let client = FakeAPIClient()
        client.responseJSON = Data(ProductJSON.page.utf8)

        let page = try await LiveProductRepository(client: client).products(sort: .priceAscending, skip: 40, limit: 20)

        #expect(client.requests == [
            FakeAPIClient.Request(path: "/products", queryItems: [
                URLQueryItem(name: "limit", value: "20"),
                URLQueryItem(name: "skip", value: "40"),
                URLQueryItem(name: "sortBy", value: "price"),
                URLQueryItem(name: "order", value: "asc"),
            ]),
        ])
        let expected = try JSONDecoder().decode(ProductListResponseDTO.self, from: client.responseJSON).toDomain()
        #expect(page == expected)
    }

    @Test func propagatesClientErrors() async {
        let client = FakeAPIClient()
        client.error = AppError.offline

        await #expect(throws: AppError.offline) {
            try await LiveProductRepository(client: client).products(sort: .defaultOrder, skip: 0, limit: 20)
        }
    }
}
