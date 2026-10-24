# 2.1.0 — The Fathers and Doctors unlock

**Status: build 29 uploaded to App Store Connect on 23 October 2026 (delivery 117f6945), not submitted for review.** Branch `release/2.1.0`.
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

## App Store Connect steps (Anton)

1. Create the in-app purchase: type Non-Consumable, product ID `com.nrsv.verse.fathers`, reference name "The Fathers and Doctors", price US$9.99, Family Sharing on. Display name "The Fathers and Doctors". Description "Every work of the Fathers and Doctors in the app, offline. One payment." Review screenshot: the reader's unlock page.
2. Upload build 29 (`scripts/native/release-testflight.sh 2.1.0 29`).
3. Create version 2.1.0, attach build 29, and **add the in-app purchase to the version in the web UI**. The first in-app purchase of an app must ship with a version. The API cannot add it.
4. Paste the 2.1.0 store text from `docs/store-text-2026-10-23.md`: name, subtitle, keywords, description. Change the primary category to Reference and the secondary to Books.
5. Review notes: "The app has one optional purchase, The Fathers and Doctors (com.nrsv.verse.fathers). To see it: Read tab › The Church Fathers › any author › any work › the › arrow at the bottom right. It is also in Settings › The Fathers & Doctors. Everything else in the app is free. People who installed before 2.1.0 keep the library free."
6. Upload the 2.1.0 screenshots from `marketing/screenshots/framed-2.1.0/`.

## Not in 2.1.0

- Android Play Billing (follows after iOS approval).
- The iOS 18 floor investigation (plan decision D6).
