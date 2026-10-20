import Foundation

public struct SaintCommemoration: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let monthDay: String
    public let name: String
    public let excerpt: String
    public let summary: String?
    public let sourceLanguage: String?
    public let observanceNote: String?
    public let sourceURL: String
    public let calendarURL: String
}

public struct SaintsCalendar: Codable, Sendable {
    public let schemaVersion: Int
    public let tradition: String
    public let sourceName: String
    public let sourceURL: String
    public let retrievedOn: String
    public let coverage: String
    public let checkedDates: [String]
    public let entries: [SaintCommemoration]

    public var title: String {
        tradition == "byzantine" ? "Byzantine Catholic · Ruthenian" : "Vatican News · Saints"
    }

    public func entries(on date: Date, timeZone: TimeZone) -> [SaintCommemoration] {
        let calendar = CompanionCalendar.gregorianCalendar(timeZone: timeZone)
        let key = String(CompanionCalendar.dateKey(date, timeZone: timeZone).suffix(5))
        // The MCI assigns Cassian to February 28 at Compline in non-leap years.
        let includeCassian = tradition == "byzantine" && key == "02-28"
            && calendar.range(of: .day, in: .month, for: date)?.count == 28
        return entries.filter { $0.monthDay == key || (includeCassian && $0.monthDay == "02-29") }
    }

    public func validate() throws {
        let hosts = tradition == "vatican" ? ["www.vaticannews.va", "www.vatican.va"] : ["mci.archpitt.org"]
        let expectedDates = tradition == "vatican" ? 365 : 366
        guard schemaVersion == 1, ["vatican", "byzantine"].contains(tradition),
              Set(checkedDates).count == expectedDates, !entries.isEmpty,
              Set(entries.map(\.id)).count == entries.count,
              entries.allSatisfy({ entry in
                  checkedDates.contains(entry.monthDay) && !entry.name.isEmpty
                      && [entry.sourceURL, entry.calendarURL].allSatisfy {
                          let url = URL(string: $0)
                          return url?.scheme == "https" && hosts.contains(url?.host ?? "")
                      }
              }) else { throw CoreError.invalidResource("saints calendar") }
    }
}

public enum SaintsNotice {
    /// Keep one notice per day, including every entry from both source calendars.
    public static func body(calendars: [SaintsCalendar], date: Date, timeZone: TimeZone, gospel: String?) -> String {
        var lines = calendars.compactMap { catalog -> String? in
            let names = catalog.entries(on: date, timeZone: timeZone).map(\.name)
            guard !names.isEmpty else { return nil }
            return "\(catalog.title): \(names.joined(separator: "; "))."
        }
        if let gospel, !gospel.isEmpty { lines.append("Roman Rite Gospel: \(gospel).") }
        lines.append("Open today’s saints and readings.")
        return lines.joined(separator: "\n")
    }
}
