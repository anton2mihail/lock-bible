# ADR 0006: iOS 26 chrome

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Status: ACCEPTED mechanism. Final L05 geometry and behavior remain open.

## Decision boundary

Use custom flat SwiftUI tab chrome. Keep the source five-tab order, exact labels, Feather forms, flat background, top border, colors, and selected state. The app's current shell is the reference.

Use standard SwiftUI navigation containers where they match the source. Build the custom bar with public APIs. System permission dialogs and share sheets retain system presentation.

The custom shell must preserve tab accessibility, selected state, minimum touch targets, bottom safe areas, keyboard behavior, and iPad width. One AppRouter owns tab selection, push paths, modal values, and queued requests. A Search result returns to the existing Reader rather than adding a duplicate tab shell.

## Acceptance

Sol inspected `build/native-evidence/L01/renderer-proof/04-shell-comparison.png` on the pinned iPhone 17 Pro iOS 26.5 simulator. The standard TabView has a floating rounded surface and filled system icons. The custom comparison has the flat top border and Feather forms. Sol compared these with the clean L00 Today/Reader bar.

This evidence chooses the custom mechanism. L05 proves final source geometry and return behavior. Full dark, keyboard, iPad, and accessibility-size checks remain L05 and later parity conditions. A proof comparison is not an all-screen visual pass.

## Amendment: system Liquid Glass tab bar

Date: 6 October 2026.
Status: ACCEPTED by owner decision. Simulator acceptance is open.

### Owner decision

The owner overrides the custom flat tab chrome above. The app uses the system SwiftUI `TabView` with the iOS 26 `Tab` API, so the tab bar is the system Liquid Glass bar. The owner also decided that pushed routes keep the iOS 26 system glass back button (audit item B1, Option 1), and that iPad keeps the tab bar (audit item B12 is rejected: no `.sidebarAdaptable`).

### What changed

- `JohnApp.swift` shows a `TabView` with five `Tab` values in source order: Today, Read, Saved, Pray, Settings. The labels are the exact source labels.
- Each `Tab` has its own `NavigationStack`. AppRouter keeps one path for each tab, so a tab change keeps the push path and the root view state of the other tabs. The Read root is the exception: it gets a new identity on each Read-tab entry (`AppRouter.readEntryID`), so each entry creates a new `ReaderView`, as before. The Reader request handling of commit 9d3753c was verified with that lifecycle.
- AppRouter is the only owner of the selection. `selectedTab` is `private(set)`. `select(_:)` changes it. The tab bar writes through `selectFromTabBar(_:)`. A tap on the selected tab pops that tab to its root (the September "Pray stranding" item).
- The icons are the brand Feather glyphs, drawn at 25 pt into template images (`FeatherIcon.templateImage`). SF Symbols are a fallback only if the font cannot draw a glyph.
- The tab bar buttons keep the accessibility identifiers `tab-today`, `tab-read`, `tab-saved`, `tab-pray`, and `tab-settings` through `TabContent.accessibilityIdentifier`.
- `.tabViewStyle(.tabBarOnly)` keeps the five-tab bar on iPad (at the top of the window on iPadOS 26).
- `.tabBarMinimizeBehavior(.onScrollDown)` applies only while the Read tab is selected. The other tabs use `.never`. In Debug builds, the launch arguments `-JohnTabBarMinimize never` turn off the minimize behavior.
- Scroll content goes under the floating bar with the default (automatic) bottom scroll edge effect. The Reader top mask now goes into the bottom safe area, so the chapter text scrolls under the glass. The top clip is the same.
- The system bar stays below the keyboard (audit item A1). The system bar shows the Large Content Viewer for tab labels at accessibility text sizes.
- `FlatTabBar.swift` and the `tintInactive` color are removed.

### Parity checks that this invalidates

- The tab bar region of all native L25 captures (all routes, all variants). The floating bar is a rounded glass surface over the content, not a flat bar with a top border. Content now shows through the bar region.
- The L01 shell comparison (`build/native-evidence/L01/renderer-proof/04-shell-comparison.png`) no longer describes the native shell.
- Geometry that uses the tab button tops as the bottom of the visible viewport (`tabTop` helpers) now measures to the glass buttons. The bar surface starts a few points above them.
- Reader, Works, and Saved bottom-control checks against the tab bar (for example `assertWorksFooter`) must run again.

### Tests

The tab identifiers did not change, so no test selector changes are necessary. These test risks remain open until a simulator run:

- After a scroll down in the Reader, the bar minimizes and shows only the selected tab. A test that then taps another tab can fail. Launch with `-JohnTabBarMinimize never`, or tap the minimized bar first.
- The system tab bar button label is the plain title (for example `Read`). VoiceOver reads it as "Read, tab, 2 of 5".
