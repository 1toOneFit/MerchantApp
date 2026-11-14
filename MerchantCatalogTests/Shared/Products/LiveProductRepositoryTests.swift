import Foundation
import Testing
@testable import MerchantCatalog

/// `LiveProductRepository` builds the list target and maps the response; it depends only on
/// `APIClientType` (Architecture § 4).
@MainActor
struct LiveProductRepositoryTests {
    @Test func requestsListTargetAndMapsPage() async throws {
        let client = FakeAPIClient()
        client.responseJSON = Data(ProductJSON.summaryPage.utf8)

        let page = try await LiveProductRepository(client: client).products(sort: .priceAscending, skip: 40, limit: 20)

        #expect(client.requests == [
            FakeAPIClient.Request(path: "/products", queryItems: [
                URLQueryItem(name: "limit", value: "20"),
                URLQueryItem(name: "skip", value: "40"),
                URLQueryItem(name: "select", value: "title,price,thumbnail,rating,category"),
                URLQueryItem(name: "sortBy", value: "price"),
                URLQueryItem(name: "order", value: "asc"),
            ]),
        ])
        let expected = try JSONDecoder().decode(ProductListResponseDTO.self, from: client.responseJSON).toDomain()
        #expect(page == expected)
    }

    @Test func requestsSearchTargetAndMapsPage() async throws {
        let client = FakeAPIClient()
        client.responseJSON = Data(ProductJSON.summaryPage.utf8)

        let page = try await LiveProductRepository(client: client).search(query: "phone", sort: .ratingDescending, skip: 40, limit: 20)

        #expect(client.requests == [
            FakeAPIClient.Request(path: "/products/search", queryItems: [
                URLQueryItem(name: "q", value: "phone"),
                URLQueryItem(name: "limit", value: "20"),
                URLQueryItem(name: "skip", value: "40"),
                URLQueryItem(name: "select", value: "title,price,thumbnail,rating,category"),
                URLQueryItem(name: "sortBy", value: "rating"),
                URLQueryItem(name: "order", value: "desc"),
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

    @Test func requestsDetailTargetAndMapsProduct() async throws {
        let client = FakeAPIClient()
        client.responseJSON = Data(ProductJSON.product.utf8)

        let product = try await LiveProductRepository(client: client).product(id: 1)

        #expect(client.requests == [FakeAPIClient.Request(path: "/products/1", queryItems: [])])
        let expected = try JSONDecoder().decode(ProductDTO.self, from: client.responseJSON).toDomain()
        #expect(product == expected)
    }

    /// An unknown id is a 404 (A6), which details opened from Saved show as "no longer available".
    @Test func detailPropagatesNotFound() async {
        let client = FakeAPIClient()
        client.error = AppError.notFound

        await #expect(throws: AppError.notFound) {
            try await LiveProductRepository(client: client).product(id: 99999)
        }
    }
}
