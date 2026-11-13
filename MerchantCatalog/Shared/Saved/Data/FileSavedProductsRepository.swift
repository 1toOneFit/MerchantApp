import Foundation

/// Saved products in `<directory>/saved-products.json` (Architecture § 9):
/// `{ "version": 1, "items": [...] }`, written atomically. An actor, so file I/O never runs on the
/// main actor and writes don't interleave.
///
/// - A file that isn't valid JSON for version 1 is moved aside as
///   `saved-products.corrupt-<yyyyMMdd'T'HHmmss'Z'>.json`, logged at `.error`, and the list starts
///   empty (ProductSpecification § 4.4).
/// - A file with another `version` (e.g. from a newer build) is left in place, logged at `.error`,
///   and the list starts empty; the next save overwrites it (D-65).
/// - Prices are stored as decimal strings and dates as ISO 8601 with milliseconds, so both round-trip
///   exactly (D-66).
actor FileSavedProductsRepository: SavedProductsRepository {
    static let fileName = "saved-products.json"
    static let currentVersion = 1

    private let directory: URL
    private let now: @Sendable () -> Date

    /// - Parameters:
    ///   - directory: holds the file; created on the first save. The app passes Application Support.
    ///   - now: names a quarantined file.
    init(directory: URL, now: @escaping @Sendable () -> Date = Date.init) {
        self.directory = directory
        self.now = now
    }

    private var fileURL: URL {
        directory.appending(path: Self.fileName)
    }

    func load() async -> [SavedProduct] {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch CocoaError.fileReadNoSuchFile {
            return []
        } catch {
            Log.persistence.error("saved products: read failed (\(Self.summary(error), privacy: .public))")
            return []
        }

        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(VersionDTO.self, from: data) else {
            quarantine(reason: "not a saved-products file")
            return []
        }
        guard header.version == Self.currentVersion else {
            Log.persistence.error("saved products: unsupported version \(header.version, privacy: .public); file left in place")
            return []
        }
        do {
            let items = try decoder.decode(FileDTO.self, from: data).items.map { try $0.toDomain() }
            Log.persistence.info("saved products: loaded \(items.count, privacy: .public)")
            return items
        } catch {
            quarantine(reason: Self.summary(error))
            return []
        }
    }

    func save(_ items: [SavedProduct]) async {
        do {
            let file = FileDTO(version: Self.currentVersion, items: items.map(ItemDTO.init))
            let data = try JSONEncoder().encode(file)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            Log.persistence.info("saved products: wrote \(items.count, privacy: .public)")
        } catch {
            Log.persistence.error("saved products: write failed (\(Self.summary(error), privacy: .public))")
        }
    }

    private func quarantine(reason: String) {
        let name = "saved-products.corrupt-\(now().formatted(Self.quarantineStamp)).json"
        do {
            try FileManager.default.moveItem(at: fileURL, to: directory.appending(path: name))
            Log.persistence.error("saved products: unreadable file (\(reason, privacy: .public)) moved to \(name, privacy: .public)")
        } catch {
            Log.persistence.error("saved products: unreadable file (\(reason, privacy: .public)); move failed (\(Self.summary(error), privacy: .public))")
        }
    }

    /// `20261113T100000Z`.
    private static let quarantineStamp = Date.ISO8601FormatStyle(dateSeparator: .omitted, timeSeparator: .omitted, timeZone: .gmt)

    /// A type and code, never a description (which can contain paths).
    private static func summary(_ error: any Error) -> String {
        if let error = error as? DecodingError {
            switch error {
            case .typeMismatch: return "DecodingError.typeMismatch"
            case .valueNotFound: return "DecodingError.valueNotFound"
            case .keyNotFound: return "DecodingError.keyNotFound"
            case .dataCorrupted: return "DecodingError.dataCorrupted"
            @unknown default: return "DecodingError"
            }
        }
        let error = error as NSError
        return "\(error.domain) \(error.code)"
    }
}

// MARK: - File format

private struct VersionDTO: Decodable {
    let version: Int
}

private struct FileDTO: Codable {
    let version: Int
    let items: [ItemDTO]
}

private struct ItemDTO: Codable {
    let id: Int
    let title: String
    let thumbnailURL: String?
    let price: String
    let rating: Double?
    let category: String?
    let savedAt: String

    private static let dateStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    init(_ item: SavedProduct) {
        id = item.id
        title = item.title
        thumbnailURL = item.thumbnailURL?.absoluteString
        price = item.price.description
        rating = item.rating
        category = item.category
        savedAt = item.savedAt.formatted(Self.dateStyle)
    }

    func toDomain() throws -> SavedProduct {
        guard let price = Decimal(string: price, locale: Locale(identifier: "en_US_POSIX")) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "price"))
        }
        return SavedProduct(
            id: id,
            title: title,
            thumbnailURL: thumbnailURL.flatMap { URL(string: $0) },
            price: price,
            rating: rating,
            category: category,
            savedAt: try Date(savedAt, strategy: Self.dateStyle)
        )
    }
}
