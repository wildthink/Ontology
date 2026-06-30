import Foundation
import Ontology

// MARK: - Google Drive API v3 — File resource

/// https://developers.google.com/drive/api/reference/rest/v3/files
public struct GDriveFile: Decodable, Sendable {
    public let id: String?
    public let name: String?
    public let description: String?
    public let mimeType: String?
    /// RFC 3339 timestamp.
    public let modifiedTime: String?
    /// Link to open the file in the browser.
    public let webViewLink: String?
}

/// Convenience wrapper for a Google Drive `files.list` response.
public struct GDriveFileList: Decodable, Sendable {
    public let files: [GDriveFile]?
}

// MARK: - Record bridge

extension Record {
    public init(_ g: GDriveFile) {
        self.init(
            identifier: g.id,
            name: g.name,
            description: g.description,
            recordedAt: g.modifiedTime
                .flatMap { DateTime.parseISO8601($0) }
                .map { DateTime($0) },
            url: g.webViewLink.flatMap { URL(string: $0) }
        )
    }
}
