import Foundation

struct Fixture: Decodable {
    let outputs: [Output]
}

struct Output: Decodable {
    let cadenceMinutes: Int
    let timezoneOffsetMinutes: Int
    let instant: String
    let localSlot: Int64
    let poolCount: Int
    let poolIndex: Int
    let nextRotationInstant: String
}

@main
struct CompareRotationNative {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            fputs("Usage: compare-rotation-native <rotation-fixtures.json>\n", stderr)
            exit(2)
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let fixtures = try JSONDecoder().decode(Fixture.self, from: data)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var errors: [String] = []
        for (index, row) in fixtures.outputs.enumerated() {
            guard let instant = formatter.date(from: row.instant),
                  let expectedBoundary = formatter.date(from: row.nextRotationInstant) else {
                errors.append("row \(index): invalid ISO date")
                continue
            }
            let offsetSeconds = -row.timezoneOffsetMinutes * 60
            do {
                let slot = try RotationMath.slot(at: instant, utcOffsetSeconds: offsetSeconds,
                                                 intervalMinutes: row.cadenceMinutes)
                let poolIndex = try RotationMath.index(for: slot, count: row.poolCount)
                let boundary = try RotationMath.nextBoundary(after: instant, utcOffsetSeconds: offsetSeconds,
                                                              intervalMinutes: row.cadenceMinutes)
                if slot != row.localSlot || poolIndex != row.poolIndex ||
                    abs(boundary.timeIntervalSince(expectedBoundary)) > 0.0005 {
                    errors.append("row \(index): slot/index/boundary mismatch")
                }
            } catch {
                errors.append("row \(index): \(error)")
            }
        }
        if errors.isEmpty {
            print("Matched \(fixtures.outputs.count) rotation rows.")
        } else {
            for error in errors.prefix(20) { fputs(error + "\n", stderr) }
            fputs("Failed \(errors.count) of \(fixtures.outputs.count) rotation rows.\n", stderr)
            exit(1)
        }
    }
}
