import CryptoKit
import Foundation
import JohnCore

/// App-only bridge from Tencent MMKV Core to JohnCore's read-only import contract.
public struct LegacyMMKVReader: LegacyMMKVReading {
    public let rootURL: URL

    public init(rootURL: URL) { self.rootURL = rootURL.standardizedFileURL }

    public init(appGroupIdentifier: String) throws {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw CoreError.missingResource("MMKV App Group container")
        }
        self.init(rootURL: url)
    }

    public func readKnownValues(_ keys: [String]) async throws -> LegacyMMKVSnapshot? {
        let dataURL = rootURL.appendingPathComponent("mmkv.default", isDirectory: false)
        let crcURL = rootURL.appendingPathComponent("mmkv.default.crc", isDirectory: false)
        let hasData = FileManager.default.fileExists(atPath: dataURL.path)
        let hasCRC = FileManager.default.fileExists(atPath: crcURL.path)
        if !hasData && !hasCRC { return nil }
        guard hasData && hasCRC else { throw CoreError.unreadableLibrary("MMKV data and CRC files are incomplete") }

        let data = try Data(contentsOf: dataURL, options: .mappedIfSafe)
        let crc = try Data(contentsOf: crcURL, options: .mappedIfSafe)
        var error: NSError?
        guard let result = JohnReadLegacyMMKV(rootURL.path, keys, &error) as? [String: Any],
              let names = result["keys"] as? [String],
              let strings = result["stringValues"] as? [String: String] else {
            if let error { throw error }
            throw CoreError.unreadableLibrary("MMKV read failed")
        }
        let hashes = [
            "mmkv.default": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            "mmkv.default.crc": SHA256.hash(data: crc).map { String(format: "%02x", $0) }.joined(),
        ]
        return LegacyMMKVSnapshot(keys: Set(names), stringValues: strings, sourceHashes: hashes)
    }
}
