# L05 shell source review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: initial review. Runtime acceptance is pending.

## Tab bar finding

The initial native bar used SpaceGrotesk at 11 points, different selected/unselected weights, 22-point icons, and a 68-point item with 7-point top padding. These values differ from the source defaults.

`src/app/(tabs)/_layout.tsx` sets colors and the top border. It does not set label typography or bar height. The installed React Navigation implementation supplies a 49-point bar plus the bottom inset, 25-point regular icons, and 10-point System medium labels below the icons. Both selected and unselected labels use that medium font.

Required action: port these defaults and compare the native result with the clean L00 capture. Keep the source's tablet horizontal-label behavior in the iPad acceptance queue. Do not use the primary SpaceGrotesk body font for tab labels without observed source evidence.

Source files: `node_modules/@react-navigation/bottom-tabs/src/views/BottomTabBar.tsx`, `BottomTabItem.tsx`, `TabBarIcon.tsx`, and `node_modules/@react-navigation/native/src/theming/fonts.tsx`.

The initial light/dark semantic colors match the source palette values. Font registration and the rest of the shell remain unobserved in the production app.

## Navigation findings

The initial router kept a permanent set of URL strings. It rejected every later tap on an equal widget URL. It also pushed a passage view above the Read root. Sol requested one new request ID for each delivery and reuse of the existing Read root.

Main Luna reports both corrections. The current router removes URL-string deduplication, clears the Read path, and publishes a new passage request. The root forwards the request to the shared reader model. Simulator checks must prove repeated equal URLs and Search-result return without an extra Reader back step.

Startup URL delivery must wait for completed native startup. The current prepared startup status does not prove import completion. Invalid destinations must retain a recoverable error state.

## Widget target findings

The first target changed widget names, descriptions, families, and bundle order. Sol requested the exact source metadata. Main Luna reports the correction. Full providers, views, shared preferences, and timelines remain L12. A compiled target is not widget parity evidence.

The pinned WidgetKit interface requires `@Sendable` completion closures for `TimelineProvider`. Sol requested those exact method signatures and value-only `Sendable` entry/provider types. Strict Swift 6 checks must stay enabled.
