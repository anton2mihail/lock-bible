import Foundation
import JohnCore

enum CheckFailure: Error { case failed(String) }
@MainActor final class TestNoticeCenter: NoticeCenter {
    var status: NoticeAuthorizationStatus = .authorized
    var requests: [NoticeRequest] = []
    var failNextAdd = false
    func authorizationStatus() async -> NoticeAuthorizationStatus { status }
    func requestAuthorization() async throws -> NoticeAuthorizationStatus { status }
    func pendingRequests() async throws -> [NoticeRequest] { requests }
    func add(_ request: NoticeRequest) async throws {
        if failNextAdd { failNextAdd = false; throw CheckFailure.failed("add") }
        requests.removeAll { $0.identifier == request.identifier }; requests.append(request)
    }
    func removePendingRequest(identifier: String) async throws { requests.removeAll { $0.identifier == identifier } }
}
@main struct MySaintsNoticeChecks {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        func read<T: Decodable>(_ path: String, _ type: T.Type) throws -> T {
            try JSONDecoder().decode(type, from: Data(contentsOf: root.appendingPathComponent(path)))
        }
        let saints = try read("src/services/companion/data/my-saints.json", [PersonalSaint].self)
        let calendars = try ["vatican", "byzantine"].map { try read("src/services/companion/data/saints-\($0).json", SaintsCalendar.self) }
        let readings = try JSONDecoder().decode(ReadingsCalendar.self, from: Data("{}".utf8))
        let celebrations = try JSONDecoder().decode(CelebrationsCalendar.self, from: Data("{}".utf8))
        let zone = TimeZone(identifier: "America/Toronto")!
        var instant = ISO8601DateFormatter().date(from: "2027-03-09T17:00:00Z")!
        var profiles = MySaintsState()
        var calendarSettings = CalendarNotificationSettings(enabled: true)
        var commits = 0, failCommit = false
        let center = TestNoticeCenter()
        let service = LocalNoticeService(center: center, now: { instant }, timeZone: { zone },
            readCommitted: { NativePersistentState(calendarNotifications: calendarSettings, saints: profiles) },
            readCalendars: { (readings, celebrations) }, commit: { mutation in
                if failCommit { throw CheckFailure.failed("commit") }
                commits += 1
                switch mutation {
                case let .setSaintProfile(id, value): profiles.profiles[id] = value
                case let .setCalendarNotifications(value): calendarSettings = value
                default: break
                }
            }, readSaints: { calendars }, readPersonalSaints: { saints })
        func check(_ value: Bool, _ message: String) throws { if !value { throw CheckFailure.failed(message) } }
        func rejected(_ block: () async throws -> Void) async throws {
            var failed = false
            do { try await block() } catch { failed = true }
            try check(failed, "expected a rejected operation")
        }
        var profile = SaintProfile(); profile.reminderEnabled = true
        profile.observanceID = saints.first { $0.id == "st-joseph" }!.commemorations[0].id
        center.status = .denied
        try await rejected { try await service.saveSaint(id: "st-joseph", profile: profile) }
        try check(commits == 0 && center.requests.isEmpty, "denied permission changed saved data")
        center.status = .authorized
        try await service.saveSaint(id: "st-joseph", profile: profile)
        let personal = center.requests.first { $0.identifier == "john-saint:st-joseph" }!
        try check(center.requests.filter { $0.trigger == personal.trigger }.count == 1, "duplicate calendar and feast alert")
        try check(personal.userInfo["url"] == "nrsv://saint?id=st-joseph&feast=1", "bad notification route")
        try check(center.requests.count <= 62 && profiles.profiles["st-joseph"]?.reminderEnabled == true, "missing saved reminder")
        let original = center.requests
        profile.reminderHour = 9; center.failNextAdd = true
        try await rejected { try await service.saveSaint(id: "st-joseph", profile: profile) }
        try check(Set(center.requests.map(\.identifier)) == Set(original.map(\.identifier)), "add failure lost requests")
        try check(center.requests.first { $0.identifier == personal.identifier } == personal, "add failure did not restore feast")
        try check(profiles.profiles["st-joseph"]?.reminderHour == 8, "add failure committed settings")
        failCommit = true
        try await rejected { try await service.saveSaint(id: "st-joseph", profile: profile) }
        try check(center.requests.first { $0.identifier == personal.identifier } == personal, "commit failure did not restore feast")
        failCommit = false
        profile.reminderEnabled = false
        try await service.saveSaint(id: "st-joseph", profile: profile)
        try check(!center.requests.contains { $0.identifier == personal.identifier }, "disabled reminder retained")
        try check(center.requests.contains { $0.identifier.hasPrefix("john-calendar:") && $0.trigger == personal.trigger }, "general calendar alert not restored")
        center.requests = (0..<62).map { NoticeRequest(identifier: "external:\($0)", title: "Other", body: "", userInfo: [:], trigger: .interval(seconds: 1000, repeats: false)) }
        profile.reminderEnabled = true
        try await rejected { try await service.saveSaint(id: "st-joseph", profile: profile) }
        try check(center.requests.count == 62 && profiles.profiles["st-joseph"]?.reminderEnabled == false, "full schedule damaged state")
        center.requests = []
        try await service.saveSaint(id: "st-joseph", profile: profile)
        instant = ISO8601DateFormatter().date(from: "2027-03-20T17:00:00Z")!
        try await service.refresh()
        if case let .calendarDate(date, _) = center.requests.first(where: { $0.identifier == personal.identifier })!.trigger {
            try check(CompanionCalendar.dateKey(date, timeZone: zone) == "2028-03-19", "refresh did not advance year")
        } else { throw CheckFailure.failed("missing calendar date") }
        print("PASS: permission denial, duplicate suppression, add rollback, commit rollback, disable, capacity, annual refresh")
    }
}
