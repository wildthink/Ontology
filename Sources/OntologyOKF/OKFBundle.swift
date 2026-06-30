import Foundation
import Ontology

/// An OKF v0.1 bundle: a directory of `.md` concept files.
///
/// Reserved filenames:
/// - `index.md` — directory listing; maps to `Collection`
/// - `log.md`   — chronological update history; maps to `[Record]`
///
/// Concept ID for each file is the path relative to `root`, minus the `.md` suffix.
public struct OKFBundle {
    public let root: URL

    public init(root: URL) {
        self.root = root.resolvingSymlinksInPath()
    }

    // MARK: - Read

    /// All non-reserved `.md` URLs under `root` (recursive), sorted by path.
    public func conceptURLs() throws -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "md" else { continue }
            let name = url.lastPathComponent
            guard name != "index.md", name != "log.md" else { continue }
            urls.append(url)
        }
        return urls.sorted { $0.path < $1.path }
    }

    /// OKF concept ID for a file URL: path relative to root, minus `.md`.
    public func conceptID(for url: URL) -> String {
        let rootPath = root.resolvingSymlinksInPath().path
        let urlPath  = url.resolvingSymlinksInPath().path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        let rel = urlPath.hasPrefix(prefix) ? String(urlPath.dropFirst(prefix.count)) : urlPath
        return rel.hasSuffix(".md") ? String(rel.dropLast(3)) : rel
    }

    /// Read `index.md` → `Collection`, if present.
    public func readIndex() throws -> Collection? {
        let url = root.appending(path: "index.md")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try OKFReader.decode(Collection.self, contentsOf: url)
    }

    // MARK: - Write

    /// Write any Entity as an OKF concept file.
    /// - Parameter path: Relative path within the bundle (e.g. `"people/jane.md"`).
    public func write<T: Entity & Encodable>(
        _ entity: T,
        to path: String,
        body: String = ""
    ) throws {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let doc = try OKFDocument(entity, body: body)
        try doc.write(to: url)
    }

    /// Write a `Collection` as `index.md`.
    public func writeIndex(_ collection: Collection, body: String = "") throws {
        let doc = try OKFDocument(collection, body: body)
        try doc.write(to: root.appending(path: "index.md"))
    }

    /// Append a `Record` entry to `log.md` (ISO 8601 date-grouped format).
    public func appendLog(_ record: Record, date: Date = Date()) throws {
        let logURL = root.appending(path: "log.md")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dateStr = formatter.string(from: date)

        var entry = "\n## \(dateStr)\n\n"
        if let name = record.name { entry += "**\(name)**\n\n" }
        if let outcome = record.outcome { entry += "\(outcome)\n" }

        if FileManager.default.fileExists(atPath: logURL.path) {
            let handle = try FileHandle(forWritingTo: logURL)
            handle.seekToEndOfFile()
            if let data = entry.data(using: .utf8) { handle.write(data) }
            try handle.close()
        } else {
            try ("# Log\n" + entry).write(to: logURL, atomically: true, encoding: .utf8)
        }
    }
}
