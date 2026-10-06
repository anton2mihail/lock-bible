#if DEBUG
import Foundation
import CoreFoundation
import JohnCore

public struct ContentFixtureReport: Codable, Sendable {
    public let passed: Bool
    public let checks: [String: Bool]
    public let observedCounts: [String: Int]
    public let mismatches: [String]
}

/// Compare source-generated calendar, progress, and Today JSON with Core outputs.
public enum ContentFixtureComparison {
    public static func run(roots: ResourceRoots, calendarFixtureURL: URL, todayFixtureURL: URL,
                           dateEdgeFixtureURL: URL, referenceFixtureURL: URL) async throws -> ContentFixtureReport {
        let repository = BundledCompanionRepository(roots: roots)
        let catalog = try await repository.devotionalCatalog()
        let readings = try await repository.readings()
        let celebrations = try await repository.celebrations()
        let calendarJSON = try object(at: calendarFixtureURL)
        let todayJSON = try object(at: todayFixtureURL)
        let dateEdgeJSON = try object(at: dateEdgeFixtureURL)
        let referenceJSON = try object(at: referenceFixtureURL)
        let timezoneName = try string(calendarJSON, ["timezone"])
        guard let zone = TimeZone(identifier: timezoneName) else { throw CoreError.invalidResource("fixture time zone") }

        var mismatches: [String] = []
        var checks: [String: Bool] = [:]
        func check(_ name: String, _ result: Bool) { checks[name] = result; if !result { mismatches.append(name) } }

        let calendarCase = try dictionary(calendarJSON, "calendar")
        let references = try stringDictionary(calendarCase, "referenceMapping")
        let actualKeys = Set(readings.dates.keys)
        check("calendar.count", readings.dates.count == 858 && references.count == 858)
        check("calendar.keys", actualKeys == Set(references.keys))
        var referenceMatches = 0
        for key in references.keys.sorted() {
            guard let entry = readings.dates[key], let expected = try? jsonData(references[key]!),
                  let actual = try? JSONEncoder.sorted.encode(entry.readings), expected == actual else {
                mismatches.append("calendar.reference.\(key)"); continue
            }
            referenceMatches += 1
        }
        check("calendar.allReferences", referenceMatches == references.count)

        let coverage = CompanionCalendar.coverage(readings.dates)
        check("calendar.coverage", coverage?.label == (try? string(calendarCase, ["coverage"])) && coverage?.count == 858)
        check("calendar.internalGap", readings.dates["2025-09-18"] == nil)

        let dateOutputs = try array(calendarCase, "dateOutputs")
        var dateOutputMatches = 0
        for raw in dateOutputs {
            guard let row = raw as? [String: Any], let key = row["date"] as? String else { continue }
            let date = CompanionCalendar.parseDate(key, fallback: Date(timeIntervalSince1970: 0), timeZone: zone)
            if equivalent(sourceCalendarValue(date, readings: readings, celebrations: celebrations, zone: zone), row) { dateOutputMatches += 1 }
            else { mismatches.append("calendar.dateOutput.\(key)") }
        }
        check("calendar.dateOutputs", dateOutputs.count == 6 && dateOutputMatches == dateOutputs.count)

        let selectorRows = try array(calendarCase, "readingsSelectors")
        var selectorMatches = 0
        for raw in selectorRows {
            guard let row = raw as? [String: Any], let selected = row["selected"] as? [String: Any],
                  let selectedKey = selected["date"] as? String, let fallbackKey = row["fallbackLocalDate"] as? String else { continue }
            let fallback = CompanionCalendar.parseDate(fallbackKey, fallback: Date(timeIntervalSince1970: 0), timeZone: zone)
            let date: Date
            if row["route"] as? String == "sunday" && row["parameter"] == nil {
                date = CompanionCalendar.upcomingSunday(fallback, timeZone: zone)
            } else {
                date = CompanionCalendar.parseDate(row["parameter"] as? String ?? fallbackKey, fallback: fallback, timeZone: zone)
            }
            let actualKey = CompanionCalendar.dateKey(date, timeZone: zone)
            let season = CompanionCalendar.season(date, timeZone: zone)
            if actualKey == selectedKey && season == (selected["season"] as? String) &&
                equivalent(sourceCalendarValue(date, readings: readings, celebrations: celebrations, zone: zone), selected) { selectorMatches += 1 }
            else { mismatches.append("calendar.selector.\(String(describing: row["route"])):\(selectedKey)") }
        }
        check("calendar.readingsSelectors", selectorRows.count == 5 && selectorMatches == selectorRows.count)

        let sundayRows = try array(calendarCase, "sundayExamples")
        let sundayMatches = sundayRows.filter { raw in
            guard let row = raw as? [String: String], let key = row["date"], let expected = row["upcoming"] else { return false }
            let date = CompanionCalendar.parseDate(key, fallback: Date(timeIntervalSince1970: 0), timeZone: zone)
            return CompanionCalendar.dateKey(CompanionCalendar.upcomingSunday(date, timeZone: zone), timeZone: zone) == expected
        }.count
        check("calendar.sundays", sundayRows.count == 3 && sundayMatches == sundayRows.count)

        let instantRows = try array(calendarCase, "instantCases")
        let instantMatches = instantRows.filter { raw in
            guard let row = raw as? [String: Any], let epoch = row["epochMilliseconds"] as? Double,
                  let expectedDate = row["localDate"] as? String, let expectedOffset = row["offsetMinutesEast"] as? Int else { return false }
            let date = Date(timeIntervalSince1970: epoch / 1_000)
            let localDate = CompanionCalendar.dateKey(date, timeZone: zone)
            return localDate == expectedDate && zone.secondsFromGMT(for: date) / 60 == expectedOffset
        }.count
        check("calendar.instants", instantRows.count == 10 && instantMatches == instantRows.count)

        let progressCase = try dictionary(calendarJSON, "novena")
        let transitionMap = try dictionary(progressCase, "transitions")
        var transitionCount = 0
        for novena in catalog.novenas {
            guard let transition = transitionMap[novena.id] as? [String: Any],
                  let steps = transition["steps"] as? [[String: Any]] else {
                mismatches.append("novena.missing.\(novena.id)"); continue
            }
            var progress = NovenaProgress()
            for step in steps {
                guard let action = step["action"] as? String,
                      let expected = try? decodeProgress(step["progress"]) else { continue }
                switch action {
                case "initial": progress = NovenaProgressSelectors.normalize(progress)
                case "setIntention": progress = NovenaProgressSelectors.setIntention(step["input"] as? String ?? "", in: progress)
                case "completeDay": progress = NovenaProgressSelectors.completeSelectedDay(progress)
                case "startAgain": progress = NovenaProgressSelectors.reset()
                default: continue
                }
                if progress == expected { transitionCount += 1 }
                else { mismatches.append("novena.\(novena.id).\(action)") }
            }
        }
        check("novena.transitions", transitionCount == catalog.novenas.count * 12)

        let callbackCase = transitionMap[catalog.novenas.first?.id ?? ""] as? [String: Any]
        let callbackRows = callbackCase?["callbackSequence"] as? [String: Any]
        let callbackSteps = callbackRows?["steps"] as? [[String: Any]] ?? []
        let initialCallback = callbackCase?["callbackSequence"] as? [String: Any]
        let callbackInitial = try? decodeProgress(initialCallback?["initialProgress"])
        var callback = callbackInitial ?? NovenaProgress()
        var callbackMatches = 0
        for step in callbackSteps {
            guard let action = step["action"] as? String, let expected = try? decodeProgress(step["progress"]) else { continue }
            switch action {
            case "selectDay": if let day = step["selectedDay"] as? Int { callback = try NovenaProgressSelectors.selectDay(day, in: callback) }
            case "completeDay": callback = NovenaProgressSelectors.completeSelectedDay(callback)
            case "startAgain": callback = NovenaProgressSelectors.reset()
            default: continue
            }
            if callback == expected { callbackMatches += 1 } else { mismatches.append("novena.callback.\(action)") }
        }
        check("novena.callbackSequence", callbackSteps.count == 7 && callbackMatches == callbackSteps.count)

        let malformed = try dictionary(progressCase, "malformedInput")
        let malformedInput = try dictionary(malformed, "input")
        let malformedExpected = try decodeProgress(malformed["expected"])
        let malformedActual = normalizeRawProgress(malformedInput)
        check("sourceFixture.malformedInputExpected", malformedActual == malformedExpected)

        let bible = BundledBibleRepository(roots: roots)
        let manifest = try await bible.manifest(for: .webCE)
        let referenceRows = try array(referenceJSON, "cases")
        let targetMatches = referenceRows.filter { raw in
            guard let row = raw as? [String: Any], let citation = row["citation"] as? String else { return false }
            let expected = row["target"] as? [String: Any]
            let actual = JohnCore.CompanionReferenceTargetParser.parse(citation, webCEBooks: manifest)
            if expected == nil { return actual == nil }
            guard let expected, let actual else { return false }
            return actual.originalCitation == citation && actual.bookCode == expected["book"] as? String &&
                actual.chapter == expected["chapter"] as? Int
        }.count
        check("companionReferenceTarget", referenceRows.count == 8 && targetMatches == referenceRows.count)

        let todayCounts = try compareToday(todayJSON, dateEdgeJSON: dateEdgeJSON, catalog: catalog,
                                          readings: readings, celebrations: celebrations, zone: zone, mismatches: &mismatches)
        checks["today.selectors"] = todayCounts.failures == 0
        if todayCounts.failures > 0 { mismatches.append("today.selectors") }
        return ContentFixtureReport(
            passed: mismatches.isEmpty,
            checks: checks,
            observedCounts: ["readings": readings.dates.count, "celebrations": celebrations.dates.count,
                             "novenas": catalog.novenas.count, "prayers": catalog.prayers.count,
                             "teachings": catalog.teachings.count, "calendarReferences": referenceMatches,
                             "dateOutputs": dateOutputMatches, "novenaTransitionSteps": transitionCount,
                             "callbackSteps": callbackMatches, "todayCases": todayCounts.cases,
                             "referenceTargets": targetMatches,
                             "malformedInputExpected": 1],
            mismatches: mismatches
        )
    }

    private static func compareToday(_ root: [String: Any], dateEdgeJSON: [String: Any], catalog: DevotionalCatalog,
                                     readings: ReadingsCalendar, celebrations: CelebrationsCalendar,
                                     zone: TimeZone, mismatches: inout [String]) throws -> (cases: Int, failures: Int) {
        var cases = 0, failures = 0
        func record(_ result: Bool, _ label: String) { cases += 1; if !result { failures += 1; mismatches.append("today.\(label)") } }
        let finite = try dictionary(root, "finiteCalendar")
        record((finite["coverage"] as? String) == "2025-08-25 to 2027-12-31" && finite["dateCount"] as? Int == readings.dates.count, "coverage")
        let dates = finite["dates"] as? [[String: Any]] ?? []
        record(dates.count == 858, "finiteCalendar.count")
        for row in dates {
            guard let key = row["date"] as? String else { record(false, "date.malformed"); continue }
            let actual = readings.dates[key]
            record(actual?.title == (row["expectedReadings"] as? [String: Any])?["title"] as? String &&
                   equivalent(actual.map { try? jsonObject($0) } ?? nil, row["expectedReadings"]), "reading.\(key)")
        }
        let sundays = try array(root, "sundaySequence")
        record(sundays.count == 7, "sunday.count")
        for raw in sundays {
            guard let row = raw as? [String: Any], let key = row["date"] as? String,
                  let expected = row["upcomingSunday"] as? String else { record(false, "sunday.malformed"); continue }
            let date = CompanionCalendar.parseDate(key, fallback: Date(timeIntervalSince1970: 0), timeZone: zone)
            record(CompanionCalendar.dateKey(CompanionCalendar.upcomingSunday(date, timeZone: zone), timeZone: zone) == expected, "sunday.\(key)")
        }
        let prayers = try array(root, "prayerBoundaries")
        record(prayers.count == 6, "prayer.count")
        for row in prayers.compactMap({ $0 as? [String: Any] }) {
            guard let hour = row["localHour"] as? Int else { record(false, "prayer.malformed"); continue }
            let actual = TodaySelectors.prayer(hour: hour)
            record(actual.id == row["prayerID"] as? String && actual.title == row["prayerTitle"] as? String, "prayer.\(hour)")
        }
        let rosaryWeekdays = try array(root, "rosaryLocalWeekdays")
        let rosaryMidnight = try array(root, "rosaryMidnightTransition")
        record(rosaryWeekdays.count == 7 && rosaryMidnight.count == 2, "rosary.count")
        for raw in rosaryWeekdays + rosaryMidnight {
            guard let row = raw as? [String: Any], let dateTime = row["localDateTime"] as? String,
                  let day = row["localWeekday"] as? Int, let expected = row["suggestedSet"] as? String else { record(false, "rosary.malformed"); continue }
            let components = dateTime.split(separator: "T", maxSplits: 1)
            let clock = components.count == 2 ? components[1].split(separator: ":") : []
            guard components.count == 2, clock.count >= 2 else { record(false, "rosary.date"); continue }
            let date = CompanionCalendar.parseDate(String(components[0]), fallback: Date(timeIntervalSince1970: 0), timeZone: zone)
            guard let hour = Int(clock[0]), let minute = Int(clock[1]) else { record(false, "rosary.time"); continue }
            let timed = gregorianDate(date, hour: hour, minute: minute, zone: zone)
            record(CompanionCalendar.gregorianCalendar(timeZone: zone).component(.weekday, from: timed) - 1 == day &&
                   TodaySelectors.rosaryWeekdaySet(date: timed, timeZone: zone) == expected, "rosary.\(dateTime)")
        }
        let novenaBlock = try dictionary(root, "novenas")
        let order = novenaBlock["catalogOrder"] as? [String] ?? []
        record(order == catalog.novenas.map(\.id), "novena.order")
        let rawProgress = novenaBlock["syntheticProgress"] as? [String: Any] ?? [:]
        var progress: [String: NovenaProgress] = [:]
        for (id, raw) in rawProgress { if let value = try? decodeProgress(raw) { progress[id] = value } }
        let ongoing = TodaySelectors.ongoingNovenas(catalog: catalog, progressByID: progress)
        let expectedActive = novenaBlock["activeInSourceOrder"] as? [[String: Any]] ?? []
        let actualActive = ongoing.map { ["id": $0.novena.id, "title": $0.novena.title, "continueSubtitle": $0.subtitle] }
        record(equivalent(actualActive, expectedActive), "novena.active")
        let sourceStates = novenaBlock["statesInSourceOrder"] as? [[String: Any]] ?? []
        let activeNovenaIDs = Set(ongoing.map { $0.novena.id })
        let actualStates = catalog.novenas.enumerated().map { index, novena -> [String: Any] in
            let p = NovenaProgressSelectors.normalize(progress[novena.id])
            let active = activeNovenaIDs.contains(novena.id)
            let next = (1...9).first { !p.completedDays.contains($0) } ?? 9
            return ["id": novena.id, "title": novena.title, "catalogIndex": index,
                    "completedDays": p.completedDays, "intention": p.intention,
                    "active": active, "continueSubtitle": active ? "Continue with day \(next)" : NSNull()]
        }
        record(sourceStates.count == 27 && equivalent(actualStates, sourceStates), "novena.states")
        let fallbackRows = try array(root, "readingFallbacks")
        record(fallbackRows.count == 6, "fallback.count")
        for row in fallbackRows.compactMap({ $0 as? [String: Any] }) {
            guard let key = row["date"] as? String, let expectedTitle = row["todayCardTitle"] as? String else { record(false, "fallback.malformed"); continue }
            let date = CompanionCalendar.parseDate(key, fallback: Date(timeIntervalSince1970: 0), timeZone: zone)
            let reading = CompanionCalendar.readings(for: date, from: readings, timeZone: zone)
            let celebration = CompanionCalendar.celebration(for: date, from: celebrations, timeZone: zone)
            let season = CompanionCalendar.season(date, timeZone: zone)
            let title = TodaySelectors.title(readings: reading, celebration: celebration, season: season)
            let expectedReadingScreenMessage = reading == nil
                ? "Reading references for this date aren’t in your offline library. Open the official readings when you’re connected."
                : nil
            record(title == expectedTitle && season == row["season"] as? String &&
                   equivalent(reading.map { try? jsonObject($0) } ?? nil, row["reading"]) &&
                   equivalent(celebration.map { ["title": $0.title, "season": $0.season, "rank": $0.rank, "color": ($0.color as Any?) ?? NSNull()] }, row["celebration"]) &&
                   expectedReadingScreenMessage == (row["readingsScreenEmptyText"] as? String), "fallback.\(key)")
        }
        let edgeKey = dateEdgeJSON["sourceDateKeyForYearOne"] as? String
        record(edgeKey == "1-01-01", "dateKey.yearOne")
        let edgeRows = dateEdgeJSON["probes"] as? [[String: Any]] ?? []
        record(edgeRows.count == 3 && dateEdgeJSON["timezone"] as? String == zone.identifier, "dateEdge.countAndZone")
        for row in edgeRows {
            guard let input = row["input"] as? String, let expected = row["actualDate"] as? String,
                  let fallback = row["fallbackDate"] as? String else { record(false, "dateEdge.malformed"); continue }
            let observed = CompanionCalendar.dateKey(
                CompanionCalendar.parseDate(input, fallback: CompanionCalendar.parseDate(fallback, fallback: Date(timeIntervalSince1970: 0), timeZone: zone), timeZone: zone),
                timeZone: zone
            )
            record(observed == expected, "dateEdge.\(input)")
        }
        return (cases, failures)
    }

    private static func gregorianDate(_ date: Date, hour: Int, minute: Int, zone: TimeZone) -> Date {
        let calendar = CompanionCalendar.gregorianCalendar(timeZone: zone)
        var parts = calendar.dateComponents([.year, .month, .day], from: date)
        parts.hour = hour; parts.minute = minute
        return calendar.date(from: parts) ?? date
    }

    private static func sourceCalendarValue(_ date: Date, readings: ReadingsCalendar,
                                            celebrations: CelebrationsCalendar, zone: TimeZone) -> [String: Any] {
        let entry = CompanionCalendar.readings(for: date, from: readings, timeZone: zone)
        let celebration = CompanionCalendar.celebration(for: date, from: celebrations, timeZone: zone)
        let season = CompanionCalendar.season(date, timeZone: zone)
        let celebrationValue: Any = celebration.map {
            ["title": $0.title, "season": $0.season, "rank": $0.rank,
             "color": $0.color.map { $0 as Any } ?? NSNull()] as [String: Any]
        } ?? NSNull()
        let readingValues = (try? jsonObject(entry?.readings ?? [])) ?? []
        let title: Any = (entry?.title ?? celebration?.title).map { $0 as Any } ?? NSNull()
        return ["date": CompanionCalendar.dateKey(date, timeZone: zone), "season": season,
                "title": title,
                "readings": readingValues, "celebration": celebrationValue]
    }

    private static func decodeProgress(_ value: Any?) throws -> NovenaProgress {
        try JSONDecoder().decode(NovenaProgress.self, from: jsonData(value ?? NSNull()))
    }

    private static func normalizeRawProgress(_ raw: [String: Any]) -> NovenaProgress {
        let completedRaw = raw["completedDays"] as? [Any] ?? []
        let completed = Array(Set(completedRaw.compactMap { value -> Int? in
            guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
            let day = number.intValue
            return (1...9).contains(day) && number.doubleValue == Double(day) ? day : nil
        })).sorted()
        let selectedNumber = raw["selectedDay"] as? NSNumber
        let selected = selectedNumber.flatMap { number in
            (1...9).contains(number.intValue) && number.doubleValue == Double(number.intValue) ? number.intValue : nil
        } ?? 1
        return NovenaProgress(completedDays: completed, selectedDay: selected, intention: raw["intention"] as? String ?? "")
    }

    private static func object(at url: URL) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else {
            throw CoreError.invalidResource("content fixture object")
        }
        return object
    }
    private static func dictionary(_ parent: [String: Any], _ key: String) throws -> [String: Any] {
        guard let value = parent[key] as? [String: Any] else { throw CoreError.invalidResource("fixture field \(key)") }
        return value
    }
    private static func dictionary(_ parent: [String: Any], _ path: [String]) throws -> [String: Any] {
        var result = parent
        for key in path { result = try dictionary(result, key) }
        return result
    }
    private static func array(_ parent: [String: Any], _ key: String) throws -> [Any] {
        guard let value = parent[key] as? [Any] else { throw CoreError.invalidResource("fixture array \(key)") }
        return value
    }
    private static func string(_ parent: [String: Any], _ path: [String]) throws -> String {
        var value: Any = parent
        for key in path {
            guard let next = (value as? [String: Any])?[key] else { throw CoreError.invalidResource("fixture string \(key)") }
            value = next
        }
        guard let result = value as? String else { throw CoreError.invalidResource("fixture string value") }
        return result
    }
    private static func stringDictionary(_ parent: [String: Any], _ key: String) throws -> [String: Any] {
        guard let value = parent[key] as? [String: Any] else { throw CoreError.invalidResource("fixture map \(key)") }
        return value
    }
    private static func jsonData(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
    }
    private static func jsonObject<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder.sorted.encode(value), options: [.fragmentsAllowed])
    }
    private static func equivalent(_ lhs: Any?, _ rhs: Any?) -> Bool {
        let leftIsNull = lhs == nil || lhs is NSNull
        let rightIsNull = rhs == nil || rhs is NSNull
        if leftIsNull || rightIsNull { return leftIsNull && rightIsNull }
        guard let lhs, let rhs, let left = try? jsonData(lhs), let right = try? jsonData(rhs) else { return false }
        return left == right
    }
}

private extension JSONEncoder {
    static var sorted: JSONEncoder { let value = JSONEncoder(); value.outputFormatting = [.sortedKeys]; return value }
}
#endif
