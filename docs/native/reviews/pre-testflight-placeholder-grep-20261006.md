# Pre-TestFlight placeholder search, 6 October 2026

Commit HEAD: `d9b1b1049940d7f8e77a08671982b2f3e775fb37`

The working tree has uncommitted Reader and test files. It also has other uncommitted paths. The search below reads this working tree.

Uncommitted paths:

- `native/John/Features/Reader/ReaderView.swift` (modified)
- `native/John/Platform/Text/ScriptureTextView.swift` (modified)
- `native/John/SimulatorSupport/ContentFlowUITests.swift` (modified)
- `native/John/SimulatorSupport/MediaNotificationUITests.swift` (modified)
- `native/John/SimulatorSupport/NativeSmokeUITests.swift` (modified)
- `native/John/SimulatorSupport/PositiveNoticeUITests.swift` (modified)
- `native/John/SimulatorSupport/SearchNoteUITests.swift` (modified)
- `native/John/SimulatorSupport/WorksSettingsUITests.swift` (modified)
- `native/John/SimulatorSupport/ReaderRegressionUITests.swift` (untracked)
- `native/John/John.xcodeproj/project.pbxproj` (modified)
- `scripts/native/project/generate-xcodeproj.py` (modified)
- `docs/native/reviews/L25-execution-20261006.md` (untracked)
- `marketing/outreach/` (untracked)

## Search

- Root: `native/John`
- File types: `.swift`, `.plist`, `.json`
- Strings, case insensitive: `placeholder`, `TODO`, `FIXME`, `not implemented`, `coming soon`, `lorem`
- This record ignores SwiftUI placeholder APIs and `init(coder:)` that is not supported.

No `.plist` file and no `.json` file matched.

No file matched `TODO`, `FIXME`, `not implemented`, or `coming soon`.

## Ignored SwiftUI placeholder APIs

These hits are input placeholder APIs. They are not unfinished work.

- `native/John/Features/Prayers/PrayerHomeView.swift:78` — `ContentInputField(placeholder:)`
- `native/John/Features/Calendar/CalendarReadingsView.swift:118` — `ContentInputField(placeholder:)`
- `native/John/Features/Calendar/CalendarReadingsView.swift:122` — `ContentInputField(placeholder:)`
- `native/John/Features/Calendar/CalendarReadingsView.swift:283` — `let placeholder: String`
- `native/John/Features/Calendar/CalendarReadingsView.swift:302` — `Text(placeholder)`
- `native/John/Features/Calendar/CalendarReadingsView.swift:311` — `TextField(placeholder, text:)`
- `native/John/Features/Guides/ConfessionView.swift:48` — `ContentInputField(placeholder:)`
- `native/John/Features/Guides/NovenaView.swift:165` — `ContentInputField(placeholder:)`

## Ignored WidgetKit placeholder methods

These hits are required `TimelineProvider.placeholder(in:)` methods. They are not SwiftUI placeholder text and they are not unfinished work.

- `native/John/Widget/JohnWidget.swift:207` — `func placeholder(in context: Context) -> VerseEntry`
- `native/John/Widget/JohnWidget.swift:225` — `func placeholder(in context: Context) -> TimerEntry`
- `native/John/Widget/JohnWidget.swift:230` — call `placeholder(in: context)`
- `native/John/Widget/JohnWidget.swift:242` — `func placeholder(in context: Context) -> DailyEntry`
- `native/John/Widget/JohnWidget.swift:249` — call `placeholder(in: context)`

## Ignored unsupported init(coder:)

The string `not implemented` did not match. One required initializer says that `init(coder:)` is not supported. This record ignores that line.

- `native/John/Platform/Text/ScriptureTextView.swift:656` — `required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }`

## Other string hits

These hits are not unfinished-work markers.

- `native/John/SimulatorSupport/AllRouteCaptureUITests.swift:708` — a test comment says "the placeholder is absent". It describes a seeded note. It is not a placeholder screen.
- `native/John/Features/Guides/NovenaView.swift:222` — `isNilOrEmpty` contains the letters `lorem`. It is not the word `lorem`.
- `native/John/Features/Guides/NovenaView.swift:399` — `var isNilOrEmpty` contains the letters `lorem`. It is not the word `lorem`.

## Result

No remaining match is a placeholder screen, a TODO, a FIXME, text that says "not implemented", text that says "coming soon", or the word `lorem`.
