import Foundation
import Testing
@testable import JohnCore

@Suite struct ReadingPreferencesTests {
    @Test func stateWithoutModeDecodesAsPages() throws {
        let json = #"{"textSize":"large","lineSpacing":"relaxed","typeface":"sans","layout":"verses"}"#
        let decoded = try JSONDecoder().decode(ReadingPreferences.self, from: Data(json.utf8))
        #expect(decoded.mode == .pages)
        #expect(decoded.textSize == .large)
        #expect(decoded.layout == .verses)
    }

    @Test func modeRoundTrips() throws {
        let value = ReadingPreferences(textSize: .small, mode: .scroll)
        let data = try JSONEncoder().encode(value)
        #expect(try JSONDecoder().decode(ReadingPreferences.self, from: data) == value)
    }

    @Test func mutationsKeepTheOtherValues() {
        var state = NativePersistentState()
        #expect(state.readingPreferences.mode == .pages)
        state.apply(.setReaderMode(.scroll))
        state.apply(.setReaderTextSize(.extraLarge))
        state.apply(.setReaderLayout(.verses))
        #expect(state.readingPreferences.mode == .scroll)
        #expect(state.readingPreferences.textSize == .extraLarge)
        #expect(state.readingPreferences.layout == .verses)
        state.apply(.setReaderMode(.pages))
        #expect(state.readingPreferences.mode == .pages)
        #expect(state.readingPreferences.textSize == .extraLarge)
    }
}
