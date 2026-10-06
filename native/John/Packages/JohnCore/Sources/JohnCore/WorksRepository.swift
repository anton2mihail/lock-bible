import Foundation
import CSQLite

public protocol WorksRepository: Sendable {
    func catalog() async throws -> WorkCatalog
    func sectionSummaries(workID: String) async throws -> [WorkSectionSummary]
    func section(workID: String, index: Int) async throws -> WorkSection
}

public actor SQLiteWorksRepository: WorksRepository {
    public static let decodedSectionLimit = 400_000
    private let roots: ResourceRoots
    private var database: SQLiteConnection?

    public init(roots: ResourceRoots) { self.roots = roots }

    /// Reads only the small catalog. It does not open or scan the Works database.
    public func catalog() async throws -> WorkCatalog {
        let url = try roots.appResource("Catalogs", "works-catalog.json")
        do { return try JSONDecoder().decode(WorkCatalog.self, from: Data(contentsOf: url)) }
        catch { throw CoreError.invalidResource("Works catalog: \(error)") }
    }

    /// Reads section labels and lengths. It does not read or decode paragraphs.
    public func sectionSummaries(workID: String) async throws -> [WorkSectionSummary] {
        guard !workID.isEmpty else { throw CoreError.invalidIdentity("Works summary request") }
        let db = try connection()
        let query = try db.prepare("SELECT idx, title, words FROM sections WHERE work_id = ? ORDER BY idx")
        try query.bind(workID, at: 1)
        var summaries: [WorkSectionSummary] = []
        while try query.step() {
            let indexValue = query.integer(0)
            let wordsValue = query.integer(2)
            guard indexValue >= 0, indexValue <= Int64(Int.max), wordsValue >= 0,
                  wordsValue <= Int64(Int.max) else {
                throw CoreError.invalidResource("Works section summary values are out of range")
            }
            summaries.append(try WorkSectionSummary(index: Int(indexValue), title: query.text(1), words: Int(wordsValue)))
        }
        return summaries
    }

    public func section(workID: String, index: Int) async throws -> WorkSection {
        guard !workID.isEmpty, index >= 0, index <= Int(Int32.max) else { throw CoreError.invalidIdentity("Works section request") }
        let db = try connection()
        let query = try db.prepare("SELECT idx, title, words, paragraphs FROM sections WHERE work_id = ? AND idx = ?")
        try query.bind(workID, at: 1)
        try query.bind(Int32(index), at: 2)
        guard try query.step() else { throw CoreError.missingSection(workID: workID, index: index) }
        let storedIndex = Int(query.integer(0))
        let title = try query.text(1)
        let words = Int(query.integer(2))
        let encoded: Data
        switch query.columnType3 {
        case SQLITE_TEXT:
            encoded = try query.textBytes(3, limit: Self.decodedSectionLimit)
        case SQLITE_BLOB:
            let compressed = try query.blob(3)
            encoded = try BoundedZlib.inflate(compressed, limit: Self.decodedSectionLimit)
        default:
            throw CoreError.damagedSection("paragraphs column type")
        }
        let paragraphs: [String]
        do { paragraphs = try JSONDecoder().decode([String].self, from: encoded) }
        catch { throw CoreError.damagedSection("paragraph JSON: \(error)") }
        return try WorkSection(index: storedIndex, title: title, words: words, paragraphs: paragraphs)
    }

    private func connection() throws -> SQLiteConnection {
        if let database { return database }
        let url = try roots.appResource("Databases", "works.db")
        guard FileManager.default.fileExists(atPath: url.path) else { throw CoreError.missingResource("works.db") }
        let db = try SQLiteConnection(url: url, readOnly: true)
        let version = try db.prepare("SELECT value FROM metadata WHERE key = 'schemaVersion'")
        guard try version.step() else { throw CoreError.invalidResource("Works database schema metadata missing") }
        let schema = version.integer(0)
        guard schema == 2 else {
            guard schema >= Int64(Int32.min), schema <= Int64(Int32.max) else {
                throw CoreError.invalidResource("Works database schema version is out of range")
            }
            throw CoreError.unsupportedSchema(Int32(schema))
        }
        let encoding = try db.prepare("SELECT value FROM metadata WHERE key = 'paragraphEncoding'")
        guard try encoding.step(), try encoding.text(0) == "zlib-json" else { throw CoreError.invalidResource("Works paragraph encoding mismatch") }
        database = db
        return db
    }
}
