import Foundation
import CryptoKit
import JohnCore

// L27 host importer harness.
//
// Commands (all paths are COPIES below build/native-evidence/L27; the tool never touches a live container):
//   stages   --container DIR --resources DIR --legacy FILE --out DIR
//            Runs: first import, restart (native-wins), a native change (revision 2), restart, repeat update.
//   die-at   --checkpoint NAME --container DIR --resources DIR --legacy FILE
//            Runs a first import and kills the process with SIGKILL at the named checkpoint.
//   resume   --container DIR --resources DIR --legacy FILE --out FILE [--inject-after-rename]
//            Runs one import (or load) and writes a JSON result. With the flag the first commit fails after the rename.
//
// Container layout: DIR/Documents/SQLite/user-library.db (+ wal, shm), DIR/Library/Application Support/John/...
// The legacy file is old-mmkv-decoded.json from the fixture (`keys` = raw strings, `dataSHA256`, `crcSHA256`).

struct FixtureReader: LegacyMMKVReading {
    let values: [String: String]
    let hashes: [String: String]
    func readKnownValues(_ keys: [String]) async throws -> LegacyMMKVSnapshot? {
        // Same selection as native/John/LegacyAdapter/LegacyMMKVAdapter.mm: all keys; values for known keys and vesper.sunday.*.
        let known = Set(keys)
        var selected: [String: String] = [:]
        for (key, value) in values where known.contains(key) || key.hasPrefix("vesper.sunday.") { selected[key] = value }
        return LegacyMMKVSnapshot(keys: Set(values.keys), stringValues: selected, sourceHashes: hashes)
    }
}

func args() -> [String: String] {
    var result: [String: String] = [:]
    var index = 2
    let all = CommandLine.arguments
    while index < all.count {
        let key = all[index]
        if key.hasPrefix("--") {
            if index + 1 < all.count, !all[index + 1].hasPrefix("--") { result[key] = all[index + 1]; index += 2 }
            else { result[key] = "1"; index += 1 }
        } else { index += 1 }
    }
    return result
}

func sha256(_ url: URL) -> String? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func protectedHashes(_ container: URL) -> [String: String] {
    let names = ["Documents/SQLite/user-library.db", "Documents/SQLite/user-library.db-wal", "Documents/SQLite/user-library.db-shm",
                 "Documents/mmkv/mmkv.default", "Documents/mmkv/mmkv.default.crc"]
    var result: [String: String] = [:]
    for name in names { result[name] = sha256(container.appendingPathComponent(name)) ?? "absent" }
    return result
}

func recoveryFiles(_ container: URL) -> [String] {
    let dir = container.appendingPathComponent("Library/Application Support/John/recovery")
    return ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).sorted()
}

func stateFiles(_ container: URL) -> [String: String] {
    let dir = container.appendingPathComponent("Library/Application Support/John")
    var result: [String: String] = [:]
    for name in ["native-state-v1.json", "native-state-v1.previous.json"] {
        result[name] = sha256(dir.appendingPathComponent(name)) ?? "absent"
    }
    return result
}

struct Inputs {
    let container: URL
    let resources: URL
    let reader: FixtureReader
}

func loadInputs(_ options: [String: String]) -> Inputs {
    guard let container = options["--container"], let resources = options["--resources"], let legacy = options["--legacy"],
          let data = try? Data(contentsOf: URL(fileURLWithPath: legacy)),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let keys = object["keys"] as? [String: String] else {
        FileHandle.standardError.write(Data("missing or invalid --container, --resources, or --legacy\n".utf8))
        exit(2)
    }
    var hashes: [String: String] = [:]
    let mmkv = URL(fileURLWithPath: container).appendingPathComponent("Documents/mmkv")
    hashes["mmkv.default"] = sha256(mmkv.appendingPathComponent("mmkv.default")) ?? ""
    hashes["mmkv.default.crc"] = sha256(mmkv.appendingPathComponent("mmkv.default.crc")) ?? ""
    return Inputs(container: URL(fileURLWithPath: container), resources: URL(fileURLWithPath: resources),
                  reader: FixtureReader(values: keys, hashes: hashes))
}

func makeStore(_ inputs: Inputs, checkpoint: (@Sendable (NativeImportCheckpoint) -> Void)? = nil,
               failure: (@Sendable (NativeStateFailurePoint) -> Bool)? = nil) -> NativeStateStore {
    NativeStateStore(applicationSupportURL: inputs.container.appendingPathComponent("Library/Application Support"),
                     libraryURL: inputs.container.appendingPathComponent("Documents/SQLite/user-library.db"),
                     roots: ResourceRoots(app: inputs.resources), legacyReader: inputs.reader,
                     checkpoint: checkpoint, failureInjector: failure)
}

func describe(_ startup: StartupState, _ inputs: Inputs) -> [String: Any] {
    [
        "revision": startup.revision.map { Int($0) } as Any? ?? NSNull(),
        "hasEnvelope": startup.envelope != nil,
        "libraryCapability": startup.libraryCapability as Any? ?? NSNull(),
        "nativeStateCapability": startup.nativeStateCapability as Any? ?? NSNull(),
        "importSourceHashes": startup.envelope?.importSourceHashes ?? [:],
        "issues": startup.envelope?.issues ?? [],
        "stateFiles": stateFiles(inputs.container),
        "recoveryFiles": recoveryFiles(inputs.container),
        "protectedFiles": protectedHashes(inputs.container),
    ]
}

func writeJSON(_ object: Any, to path: String) {
    let data = try! JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try! data.write(to: URL(fileURLWithPath: path))
}

func copyEnvelope(_ inputs: Inputs, to directory: URL, name: String) {
    let source = inputs.container.appendingPathComponent("Library/Application Support/John/native-state-v1.json")
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    try? FileManager.default.copyItem(at: source, to: directory.appendingPathComponent(name))
}

let command = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""
let options = args()

switch command {
case "stages":
    let inputs = loadInputs(options)
    guard let out = options["--out"] else { exit(2) }
    let outURL = URL(fileURLWithPath: out)
    try FileManager.default.createDirectory(at: outURL, withIntermediateDirectories: true)
    var report: [String: Any] = ["beforeProtected": protectedHashes(inputs.container)]
    // Stage 1: first import. No native file exists yet.
    var startup = await makeStore(inputs).loadOrImport()
    report["stage1FirstImport"] = describe(startup, inputs)
    copyEnvelope(inputs, to: outURL, name: "stage1-native-state-v1.json")
    // Stage 2: restart. A new store reads the valid envelope. The legacy reader stays available and must not matter.
    startup = await makeStore(inputs).loadOrImport()
    report["stage2NativeWinsRestart"] = describe(startup, inputs)
    copyEnvelope(inputs, to: outURL, name: "stage2-native-state-v1.json")
    // Stage 3: a native change (the same action as the L04 rehearsal: text size large). Revision 2.
    let changeStore = makeStore(inputs)
    _ = await changeStore.loadOrImport()
    let updated = try await changeStore.update(.setReaderTextSize(.large))
    report["stage3NativeChangeRevision"] = Int(updated.revision)
    startup = await makeStore(inputs).loadOrImport()
    report["stage3AfterChangeRestart"] = describe(startup, inputs)
    copyEnvelope(inputs, to: outURL, name: "stage3-native-state-v1.json")
    // Stage 4: repeat update. A new process start with the same legacy files. No import, no new backup.
    startup = await makeStore(inputs).loadOrImport()
    report["stage4RepeatUpdate"] = describe(startup, inputs)
    copyEnvelope(inputs, to: outURL, name: "stage4-native-state-v1.json")
    report["afterProtected"] = protectedHashes(inputs.container)
    writeJSON(report, to: outURL.appendingPathComponent("stages-report.json").path)
    print("stages complete")
case "die-at":
    let inputs = loadInputs(options)
    guard let name = options["--checkpoint"], let target = NativeImportCheckpoint(rawValue: name) else {
        FileHandle.standardError.write(Data("unknown --checkpoint\n".utf8)); exit(2)
    }
    let store = makeStore(inputs, checkpoint: { point in
        if point == target { kill(getpid(), SIGKILL) }
    })
    _ = await store.loadOrImport()
    print("process was not killed: checkpoint \(name) was not reached")
    exit(3)
case "resume":
    let inputs = loadInputs(options)
    guard let out = options["--out"] else { exit(2) }
    let inject = options["--inject-after-rename"] != nil
    let store = inject ? makeStore(inputs, failure: { $0 == .afterPrimaryRename }) : makeStore(inputs)
    let startup = await store.loadOrImport()
    writeJSON(describe(startup, inputs), to: out)
    print("resume complete")
default:
    FileHandle.standardError.write(Data("usage: L27HostImporter stages|die-at|resume ...\n".utf8))
    exit(2)
}
