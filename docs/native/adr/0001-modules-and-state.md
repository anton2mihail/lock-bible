# ADR 0001: modules and state

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Status: ACCEPTED for the independent Core and module boundary. Full S01 renderer/chrome approval remains pending.

## Decision

Use a feature-organized SwiftUI app and a small local JohnCore package. The tracked project path is `native/John/John.xcodeproj`. The package path is `native/John/Packages/JohnCore/`. Keep the generated Expo `/ios` project as the old reference.

Use Swift 6 with strict concurrency. Use iOS/iPadOS 26.0 as the deployment floor. Simulator support calls the same repository and renderer code used by the app. Keep scenario controls out of Release builds. Do not add a unit-test target by default.

JohnCore owns immutable domain values, pure Scripture structure, rotation math, calendar logic, catalog models, repository contracts, repository implementations, and state normalization. It must not import SwiftUI or UIKit. Resource roots and the clock are injected. Bundle lookup does not assume `Bundle.main` inside the package.

The app owns `@MainActor @Observable` feature models, typed navigation, design tokens, platform adapters, and SwiftUI views. A view sends actions to its model. It does not issue SQL, read MMKV, schedule notifications, or load a full content corpus.

Each writable SQLite handle has one actor owner. Read-only repositories also own their handles and prepared statements. Do not return a handle or statement across an actor boundary. A transaction must not suspend between `BEGIN` and `COMMIT`. Return immutable `Sendable` values.

One preference model supplies live Aa and Settings values. Feature models own transient selection, sheets, unsaved editor text, and guide state. Confession notes stay in memory and clear at the required lifecycle boundaries. They never enter the preference envelope or diagnostics.

The widget imports the shared domain, clock math, calendar data, and rotation reader. It does not depend on the legacy MMKV adapter or private state. Main Luna owns widget integration and all project target files.

## Evidence and limits

The existing source separates content, SQLite data, preferences, and widgets. The copied-byte simulator proof supports system SQLite FTS5 and bounded zlib decode. These boundaries preserve those working formats and keep the importer out of widget code.

L02 must prove a clean build and launch. L04 must prove the actor and migration behavior. L01 renderer and same-ID evidence remain required before S01 approval.
