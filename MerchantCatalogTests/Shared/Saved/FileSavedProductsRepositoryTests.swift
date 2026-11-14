import Foundation
import Testing
@testable import MerchantCatalog

/// The saved-products file (Architecture § 9): a versioned JSON envelope written atomically by an
/// actor; invalid JSON is quarantined, an unknown version is left in place (D-65).
struct FileSavedProductsRepositoryTests {
    private let directory = TemporaryDirectory()

    private var fileURL: URL {
        directory.url.appending(path: FileSavedProductsRepository.fileName)
    }

    private func makeRepository() -> FileSavedProductsRepository {
        FileSavedProductsRepository(directory: directory.url, now: { date("2026-11-13T10:00:00Z") })
    }

    private func writeFile(_ text: String) throws {
        try FileManager.default.createDirectory(at: directory.url, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: fileURL)
    }

    private static let lamp = SavedProduct(
        summary: ProductSummary(
            id: 7,
            title: "Desk Lamp",
            price: Decimal(string: "9.99")!,
            thumbnailURL: URL(string: "https://cdn.dummyjson.com/products/7/thumbnail.webp"),
            rating: 4.5,
            category: "home-decoration"
        ),
        savedAt: date("2026-11-13T09:30:00Z") + 0.25
    )
    private static let watch = SavedProduct(
        summary: ProductSummary(
            id: 3,
            title: "Watch",
            price: Decimal(string: "1899.99")!,
            thumbnailURL: nil,
            rating: nil,
            category: nil
        ),
        savedAt: date("2026-11-12T08:00:00Z")
    )

    @Test func missingFileLoadsEmpty() async {
        #expect(await makeRepository().load() == [])
    }

    @Test func roundTripKeepsItemsOrderAndPrices() async {
        await makeRepository().save([Self.lamp, Self.watch])

        let loaded = await makeRepository().load()

        #expect(loaded == [Self.lamp, Self.watch])
    }

    @Test func writesTheVersionedEnvelope() async throws {
        await makeRepository().save([Self.lamp])

        let object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any])
        let items = try #require(object["items"] as? [[String: Any]])
        #expect(object["version"] as? Int == 1)
        #expect(items.count == 1)
        #expect(items.first?["id"] as? Int == 7)
        #expect(items.first?["price"] as? String == "9.99")
        #expect(items.first?["savedAt"] as? String == "2026-11-13T09:30:00.250Z")
        // D-82 reshaped the type, not the file: the same flat fields as before.
        #expect(Set(items.first?.keys ?? [:].keys) == ["id", "title", "thumbnailURL", "price", "rating", "category", "savedAt"])
    }

    /// A file written before D-82 (flat fields, version 1) loads into the summary-based type.
    @Test func readsAFileWrittenBeforeTheSummaryShape() async throws {
        try writeFile("""
        {"version": 1, "items": [{"id": 7, "title": "Desk Lamp", "thumbnailURL": "https://cdn.dummyjson.com/products/7/thumbnail.webp", "price": "9.99", "rating": 4.5, "category": "home-decoration", "savedAt": "2026-11-13T09:30:00.250Z"}]}
        """)

        #expect(await makeRepository().load() == [Self.lamp])
    }

    @Test func saveReplacesPreviousContents() async {
        let repository = makeRepository()
        await repository.save([Self.lamp, Self.watch])

        await repository.save([Self.watch])

        #expect(await repository.load() == [Self.watch])
    }

    @Test func saveCreatesTheDirectory() async {
        await makeRepository().save([Self.lamp])

        #expect(directory.fileNames() == [FileSavedProductsRepository.fileName])
    }

    @Test func corruptFileIsQuarantined() async throws {
        try writeFile("{ not json")

        let loaded = await makeRepository().load()

        #expect(loaded == [])
        #expect(directory.fileNames() == ["saved-products.corrupt-20261113T100000Z.json"])
        let moved = try String(contentsOf: directory.url.appending(path: "saved-products.corrupt-20261113T100000Z.json"), encoding: .utf8)
        #expect(moved == "{ not json")
    }

    /// Valid JSON whose items don't decode counts as corrupt too.
    @Test func undecodableItemsAreQuarantined() async throws {
        try writeFile(#"{ "version": 1, "items": [{ "id": "seven" }] }"#)

        #expect(await makeRepository().load() == [])
        #expect(directory.fileNames() == ["saved-products.corrupt-20261113T100000Z.json"])
    }

    /// D-65: a file from a newer format stays where it is.
    @Test func unsupportedVersionIsLeftInPlace() async throws {
        let text = #"{ "version": 2, "items": [] }"#
        try writeFile(text)

        #expect(await makeRepository().load() == [])
        #expect(directory.fileNames() == [FileSavedProductsRepository.fileName])
        #expect(try String(contentsOf: fileURL, encoding: .utf8) == text)
    }
}
