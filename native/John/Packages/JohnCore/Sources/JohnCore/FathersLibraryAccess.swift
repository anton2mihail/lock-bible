import Foundation

/// Who can read which part of the Fathers and Doctors library (2.1.0).
///
/// The library is a one-time, non-consumable purchase. Everything a person needs to pray stays free.
/// Without the purchase, a reader gets a sample: the first section of every work, the whole of
/// the Apostolic Fathers, and the whole of Augustine's Confessions.
///
/// People who installed the app before the purchase existed keep the full library (grandfathering).
/// StoreKit's `AppTransaction.originalAppVersion` is the `CFBundleVersion` (build number) of the first
/// download on iOS. Builds of John 1:1 are whole numbers that only increase (1.2.0 was 13, 2.0.3 was 28),
/// so a first download before build `firstPaidBuild` means the person had the library free.
public enum FathersLibraryAccess {
    public static let productID = "com.nrsv.verse.fathers"
    /// The first build that sells the library. Every earlier build gave it away.
    public static let firstPaidBuild = 29
    /// Sections readable in every work without the purchase.
    public static let sampleSectionCount = 1
    public static let freeCollectionIDs: Set<String> = ["apostolic-fathers"]
    public static let freeWorkIDs: Set<String> = ["augustine.the-confessions"]

    /// The collection id is the part of a work id before the first dot (checked for all 271 works).
    public static func collectionID(ofWork workID: String) -> String? {
        guard let dot = workID.firstIndex(of: "."), dot != workID.startIndex else { return nil }
        return String(workID[..<dot])
    }

    /// True when this section can be read without the purchase.
    public static func isSectionFree(workID: String, index: Int) -> Bool {
        if index >= 0, index < sampleSectionCount { return true }
        if freeWorkIDs.contains(workID) { return true }
        if let collection = collectionID(ofWork: workID), freeCollectionIDs.contains(collection) { return true }
        return false
    }

    /// True when the whole work reads free, so the reader shows no unlock notice for it.
    public static func isWorkFree(workID: String, sectionCount: Int) -> Bool {
        sectionCount <= sampleSectionCount || isSectionFree(workID: workID, index: sampleSectionCount)
    }

    /// Where the app's original download came from. Only a production App Store download carries a real
    /// original build number. Sandbox, TestFlight and Xcode downloads report "1.0" or a test value.
    public enum DownloadEnvironment: Sendable { case production, sandbox, xcode }

    /// True when the first download predates the purchase. Unknown or malformed values never grandfather.
    public static func isGrandfathered(originalAppVersion: String, environment: DownloadEnvironment) -> Bool {
        guard environment == .production else { return false }
        let trimmed = originalAppVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        let leading = trimmed.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        guard !leading.isEmpty, leading.allSatisfy(\.isASCII), leading.allSatisfy(\.isNumber),
              let build = Int(leading) else { return false }
        return build < firstPaidBuild
    }
}

/// Thrown when a locked section is requested without the purchase.
public struct FathersLibraryLockedError: Error, Equatable, Sendable {
    public let workID: String
    public let index: Int
    public init(workID: String, index: Int) { self.workID = workID; self.index = index }
}
