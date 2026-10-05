import CryptoKit
import Foundation
import JohnCore

#if DEBUG
private func JohnLegacyReaderStage(_ stage: String) {
    NSLog("[JohnLegacyMMKVReader] stage=%@", stage)
}
#endif

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
#if DEBUG
        JohnLegacyReaderStage("entry")
#endif
        let dataURL = rootURL.appendingPathComponent("mmkv.default", isDirectory: false)
        let crcURL = rootURL.appendingPathComponent("mmkv.default.crc", isDirectory: false)
        let hasData = FileManager.default.fileExists(atPath: dataURL.path)
        let hasCRC = FileManager.default.fileExists(atPath: crcURL.path)
        if !hasData && !hasCRC { return nil }
        guard hasData && hasCRC else { throw CoreError.unreadableLibrary("MMKV data and CRC files are incomplete") }

        let data: Data
        let crc: Data
        do {
#if DEBUG
            JohnLegacyReaderStage("before-data-read")
#endif
            data = try Data(contentsOf: dataURL, options: .mappedIfSafe)
            crc = try Data(contentsOf: crcURL, options: .mappedIfSafe)
#if DEBUG
            JohnLegacyReaderStage("after-data-read")
#endif
        } catch {
#if DEBUG
            JohnLegacyReaderStage("data-read-failed")
#endif
            throw error
        }
        var error: NSError?
#if DEBUG
        JohnLegacyReaderStage("before-bridge")
#endif
        let bridgeResult = JohnReadLegacyMMKV(rootURL.path, keys, &error)
#if DEBUG
        JohnLegacyReaderStage("after-bridge")
#endif
        guard let result = bridgeResult,
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
