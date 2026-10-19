import Foundation
import CryptoKit

actor ModelCache {
    static let shared = ModelCache()
    private let limit = 64 * 1024 * 1024
    func load(_ url: URL) async throws -> Data {
        guard url.scheme == "https" else { throw URLError(.unsupportedURL) }
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Models")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let key = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        let path = directory.appendingPathComponent(key)
        if let data = try? Data(contentsOf: path), (try? ModelDocument(data: data)) != nil {
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: path.path)
            return data
        }
        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200, response.url?.scheme == "https",
              response.expectedContentLength <= limit else { throw URLError(.badServerResponse) }
        var data = Data()
        for try await byte in bytes {
            if data.count >= limit { throw URLError(.dataLengthExceedsMaximum) }
            if data.count % 65536 == 0 { try Task.checkCancellation() }
            data.append(byte)
        }
        _ = try ModelDocument(data: data)
        try Task.checkCancellation()
        // Bound disk growth; modification date is used as a last-access approximation.
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
        let entries = try files.map { url -> (URL, Int, Date) in
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }.sorted { $0.2 < $1.2 }
        var total = entries.reduce(data.count) { $0 + $1.1 }
        for (url, size, _) in entries where total > 256 * 1024 * 1024 {
            try FileManager.default.removeItem(at: url); total -= size
        }
        try data.write(to: path, options: .atomic)
        return data
    }
    func clear() throws {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Models")
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }
}
