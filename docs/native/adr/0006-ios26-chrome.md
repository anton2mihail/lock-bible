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
