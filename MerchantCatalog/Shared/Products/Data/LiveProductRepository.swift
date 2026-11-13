/// Loads products from the API through `APIClientType` and maps DTOs to the domain; DTOs never
/// leave this layer (Architecture § 3).
struct LiveProductRepository: ProductRepository {
    private let client: any APIClientType

    init(client: any APIClientType) {
        self.client = client
    }

    /// Runs off the main actor, so mapping a page never blocks the UI.
    @concurrent
    func products(sort: ProductSort, skip: Int, limit: Int) async throws -> ProductPage {
        let response: ProductListResponseDTO = try await client.request(
            ProductsTarget.list(skip: skip, limit: limit, sort: sort)
        )
        return response.toDomain()
    }
}
