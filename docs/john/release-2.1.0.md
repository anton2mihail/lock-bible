# 2.1.0 — The Fathers and Doctors unlock

**Status: build 29 uploaded and the 2.1.0 version, in-app purchase and store page prepared in App Store Connect on 23 October 2026. Not submitted for review.** Branch `release/2.1.0`.
Plan: [`../store-conversion-and-first-unlock-plan.md`](../store-conversion-and-first-unlock-plan.md). Store text: [`../store-text-2026-10-23.md`](../store-text-2026-10-23.md).

## What changed

**One purchase.** `com.nrsv.verse.fathers`, a non-consumable, US$9.99, Family Sharing on. It unlocks every section of the Fathers and Doctors library. Nothing else in the app is paid, and there is no subscription.

**The free sample.** Without the purchase a reader can read:

- the first section of every work (69 of the 271 works have only one section, so they read in full),
- every work of the Apostolic Fathers,
- Augustine's *Confessions*.

**Grandfathering.** Anyone whose first download was before build 29 keeps the full library free. The app reads `AppTransaction.originalAppVersion`, which on iOS is the build number of the first download. Only a production App Store download counts. Sandbox, TestFlight and Xcode installs never grandfather. **Upload 2.1.0 as build 29 or later.** Builds 13 to 28 were all free releases.

**Where the purchase is.** A reviewer or a reader finds it in three places:

1. The reader, in place of any locked section ("Read the whole library", price, Buy, Restore Purchases).
2. The library page, a "Free to start" card under the title.
3. Settings › The Fathers & Doctors, with Restore Purchases under it.

**Rating prompt.** The app asks for an App Store rating right after a person finishes a whole Rosary or marks a novena day complete, and only when they have done that three times or opened the app on seven different days. At most once every 120 days. Apple may still show nothing.

**Privacy manifest.** The app manifest now also declares `CA92.1` for the app's own UserDefaults. The app already used them before 2.1.0 (search history, sync and read-aloud settings); only the App Group reason was declared.

## Code

| Area | File |
| --- | --- |
| Access rules (sample, grandfathering) | `native/John/Packages/JohnCore/Sources/JohnCore/FathersLibraryAccess.swift` |
| Rating rule | `native/John/Packages/JohnCore/Sources/JohnCore/ReviewPromptPolicy.swift` |
| StoreKit 2 store: purchase, restore, listener, offline cache | `native/John/App/FathersLibraryStore.swift` |
| Rating counters | `native/John/App/ReviewPrompt.swift` |
| Unlock page | `native/John/Features/Works/FathersUnlockView.swift` |
| The gate (every section read) | `JohnRuntime.workSection` in `native/John/App/Runtime.swift` |
| Local StoreKit configuration | `native/John/SimulatorSupport/John.storekit` (also set on the John Development scheme's Run action) |

Debug-only launch arguments: `-JohnFathersAccess locked|purchased|grandfathered` forces the access state, and the rating prompt is off in Debug builds unless `-JohnReviewPromptEnabled` is passed.

## Checks

- Core tests: `swift test` in `native/John/Packages/JohnCore` (66 tests, including the 11 access-rule cases and 5 rating-rule cases, each mapped to a written failure list).
- Purchase end to end: `scripts/native/run-tests.sh FathersUnlockUITests`. It reads section 1, sees the unlock page with the StoreKit price on section 2, buys, reads section 2 in place, relaunches and reads it again.
- Simulator, by eye: the library card, the locked reader page and the Settings section (light mode, iPhone 17 Pro).

## App Store Connect state (23 October 2026)

Done in App Store Connect:

1. Build 29 processed; it is in TestFlight for the internal group.
2. In-app purchase created: The Fathers and Doctors, `com.nrsv.verse.fathers`, Non-Consumable, Apple ID 6826456979. US$9.99 base price, Apple's equivalents in all 175 countries and regions, Family Sharing on (permanent). Display name "The Fathers and Doctors", description "All 271 works of the Fathers and Doctors, offline." Review screenshot (reader unlock page) and review notes added. It sits in a draft review submission.
3. Version 2.1.0 created with build 29. Promotional text, description, What's New, keywords and App Review notes set from `docs/store-text-2026-10-23.md`.
4. Screenshots replaced in the 2.1.0 draft: 6 iPhone 6.9-inch and 4 iPad 13-inch slides from `marketing/screenshots/framed-2.1.0/`.
5. App Information (ships with 2.1.0): name "John 1:1 - Catholic Bible", subtitle "Rosary, Mass Readings & Saints", primary category Reference, secondary Books.

Left for Anton:

1. On the 2.1.0 version page, click Add for Review and choose the existing draft submission, so the version joins the in-app purchase.
2. Optional: test buying and restoring on a device with TestFlight and a sandbox account.
3. Submit for Review when ready.

## Not in 2.1.0

- Android Play Billing (follows after iOS approval).
- The iOS 18 floor investigation (plan decision D6).
