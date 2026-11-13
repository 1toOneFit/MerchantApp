import Foundation

/// A directory unique to one test, under the system temporary directory; removed when the instance
/// is released. Holding one as a stored property gives every Swift Testing test its own directory.
final class TemporaryDirectory {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appending(path: "MerchantCatalogTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    /// The names of the files in the directory, sorted; empty if it doesn't exist.
    func fileNames() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: url.path(percentEncoded: false))) ?? []).sorted()
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
