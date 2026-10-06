# Reader parity checks

Main owns test-target membership, fresh task-only seeds, and simulator runs. This file contains three independent UI journeys. It does not use a product-only route or a debug seed that opens a chapter.

## Source fixture

The expected text comes from the accepted nine-case fixture at `build/native-evidence/L04/repository/bible-fixtures-v2.json` (SHA-256 `5c1bc5f117681e7b8fa74a4402a4680ccb27022d6f26a4860caf6b3e327588b0`). Its generator is `scripts/native/source-fixtures/l04/bible-repository-fixtures.ts` (SHA-256 `8bced9f60dd16fbf52bfa363ffc8fb5e2bd28ec6082e56370d37af42106df53e`). The cases are John 1, Psalms 23, and Song of Solomon 1 for `web-ce`, `douay-rheims`, and `vulgate`. The test records each edition's actual source book name, first and last verse label and text, and attribution.

## Seed and profile

Each method needs a fresh task-only seed. The Reader must open at the book list. The seed must have no saved Reader location and no active verse selection. The seed must not force an edition. The tests set Medium, Comfortable, Serif, and the required layout through visible Settings controls. The native run waits for the `Selected` value. The baseline run records the observed radio value or `unresolved`. The nine-case method sets Paragraphs. The range method sets Verse by verse. The appearance preference stays unchanged. The test logs that preference. Main must record the effective simulator appearance separately. A `System` preference does not prove that the simulator uses Light or Dark appearance.

## Journeys

`testBibleRepositoryCasesAcrossEditions` visits all nine fixture cases through the visible Read tab, book, and chapter controls. Set `READER_PARITY_VARIANT` to `baseline` or `native`. Set the matching `READER_PARITY_BASELINE_BUNDLE_ID` or `READER_PARITY_NATIVE_BUNDLE_ID`. Set optional `READER_PARITY_CASE` to one exact fixture key for a one-case preflight. An unknown key fails the test. The default runs all nine cases. Run the same test method once for each app. The baseline adapter uses source labels such as `Read`, `Settings`, `John, 21 chapters`, and `John chapter 1`. It does not use native-only accessibility IDs. Main must confirm these labels in the observed hierarchy before a full run. The test captures the natural chapter top before it scrolls to the last verse. It checks first and last source text and the edition attribution. Screenshots have a variant-edition-book-chapter name. The test logs requested profile separately from observed state, plus caller-supplied app version, device, seed, and effective appearance. Supply `READER_PARITY_APP_VERSION`, `READER_PARITY_DEVICE`, `READER_PARITY_SEED`, and `READER_PARITY_EFFECTIVE_APPEARANCE` to the test runner.

`testGoToExpandsCurrentChapterAndReturnsThroughVisibleControls` opens Go To from John 1. It checks the expanded current book and chapter, selects Psalms 23 through the visible list, and returns through the Reader Back controls.

`testVerseLayoutRangeTransitionsAndSameEndRules` selects 10, 10–12, 8–12, and 8–11. It checks each exact summary and reference. It checks that a repeated endpoint keeps a multi-verse range. It closes the range, then checks that a repeated singleton clears.

## Matched visual captures

Native text assertions do not prove paragraph or poetry rendering parity. Main must capture the same nine source cases in the old app and the native app before it closes the visual comparison. Use the real book and chapter controls in each app. Keep the edition, device, Medium size, Comfortable line spacing, Serif typeface, Paragraphs layout, appearance preference, effective simulator appearance, and seed profile matched. Record the actual app version and both appearance values for each capture. Do not assume old-app accessibility IDs match native IDs. Resolve old-app selectors from its observed hierarchy. Preserve the actual screenshot bytes and metadata for review.

The source parses the test file. Target compilation and runtime checks remain pending. The verse-layout range method checks visible verse controls. It does not prove selection from paragraph-owned ink. The Go To method does not check Aa semantic value because that value is outside this test contract. Reader anchor persistence, full layout parity, and visual acceptance remain separate checks.
