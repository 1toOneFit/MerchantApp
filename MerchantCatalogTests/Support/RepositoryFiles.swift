import Foundation

/// Reads files from the repository checkout for source-scan tests (`NavigationRuleTests`,
/// `TaxonomyDocumentationTests`). The test host runs in the Simulator on the same Mac, so
/// `#filePath` points into the checkout.
enum RepositoryFiles {
    /// Walks up from `file` to the folder that contains `MerchantCatalog.xcodeproj`.
    static func root(from file: String = #filePath) -> URL? {
        var directory = URL(filePath: file).deletingLastPathComponent()
        while directory.pathComponents.count > 1 {
            let project = directory.appending(path: "MerchantCatalog.xcodeproj")
            if FileManager.default.fileExists(atPath: project.path(percentEncoded: false)) {
                return directory
            }
            directory = directory.deletingLastPathComponent()
        }
        return nil
    }

    /// Contents of every `.swift` file under `folder`, keyed by path relative to `root`.
    static func swiftSources(in folder: String, root: URL) throws -> [String: String] {
        let enumerator = FileManager.default.enumerator(
            at: root.appending(path: folder),
            includingPropertiesForKeys: nil
        )
        var sources: [String: String] = [:]
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let relative = url.pathComponents.dropFirst(root.pathComponents.count).joined(separator: "/")
            sources[relative] = try String(contentsOf: url, encoding: .utf8)
        }
        return sources
    }

    /// Contents of the file at `relativePath` under `root`.
    static func text(at relativePath: String, root: URL) throws -> String {
        try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
    }
}
