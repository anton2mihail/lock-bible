import Foundation

/// Pure rotation arithmetic that matches `src/services/bible/verseOfDay.ts`.
public enum RotationMath {
    private static let baseStride: Int64 = 104_729
    private static let shuffleOffset: Int64 = 1_729
    private static let minuteMilliseconds: Double = 60_000

    /// Return whole local-time cadence slots since the Unix epoch.
    public static func slot(at instant: Date, utcOffsetSeconds: Int, intervalMinutes: Int) throws -> Int64 {
        guard intervalMinutes > 0 else { throw CoreError.invalidIdentity("rotation interval") }
        let localMilliseconds = instant.timeIntervalSince1970 * 1_000 + Double(utcOffsetSeconds) * 1_000
        let slot = floor(localMilliseconds / (Double(intervalMinutes) * minuteMilliseconds))
        guard let exact = Int64(exactly: slot) else { throw CoreError.invalidIdentity("rotation slot range") }
        return exact
    }

    /// Map a slot into the same full-cycle permutation as the JavaScript source.
    public static func index(for slot: Int64, count: Int) throws -> Int {
        guard count >= 0 else { throw CoreError.invalidIdentity("rotation pool count") }
        if count == 0 { return 0 }
        guard let count64 = Int64(exactly: count), count64 <= Int64.max / 2 else {
            throw CoreError.invalidIdentity("rotation pool count range")
        }
        var stride = baseStride
        while greatestCommonDivisor(stride, count64) != 1 {
            guard stride <= Int64.max - 2 else { throw CoreError.invalidIdentity("rotation stride range") }
            stride += 2
        }
        let (product, overflow) = slot.multipliedReportingOverflow(by: stride)
        guard !overflow else { throw CoreError.invalidIdentity("rotation product range") }
        let (sum, sumOverflow) = product.addingReportingOverflow(shuffleOffset)
        guard !sumOverflow else { throw CoreError.invalidIdentity("rotation index range") }
        let remainder = sum % count64
        return Int((remainder + count64) % count64)
    }

    /// Return the next source boundary. It uses the current offset, as the source does.
    public static func nextBoundary(after instant: Date, utcOffsetSeconds: Int, intervalMinutes: Int) throws -> Date {
        let current = try slot(at: instant, utcOffsetSeconds: utcOffsetSeconds, intervalMinutes: intervalMinutes)
        let (nextSlot, overflow) = current.addingReportingOverflow(1)
        guard !overflow else { throw CoreError.invalidIdentity("next rotation slot range") }
        let localMilliseconds = Double(nextSlot) * Double(intervalMinutes) * minuteMilliseconds
        let absoluteMilliseconds = localMilliseconds - Double(utcOffsetSeconds) * 1_000
        guard absoluteMilliseconds.isFinite else { throw CoreError.invalidIdentity("next rotation boundary range") }
        return Date(timeIntervalSince1970: absoluteMilliseconds / 1_000)
    }

    /// OT includes deuterocanonical books, and each scope keeps the source pool order.
    public static func scopeMatches(group: String, scope: RotationScope) -> Bool {
        switch scope {
        case .full: return true
        case .ot: return group == "ot" || group == "deutero"
        case .nt: return group == "nt"
        }
    }

    private static func greatestCommonDivisor(_ left: Int64, _ right: Int64) -> Int64 {
        var x = abs(left)
        var y = abs(right)
        while y != 0 { let remainder = x % y; x = y; y = remainder }
        return x
    }
}
