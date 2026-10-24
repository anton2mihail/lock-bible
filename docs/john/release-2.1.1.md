# 2.1.1 — Interface polish

**Status: built and checked on the simulator. Not uploaded, not submitted.** Branch `ui/2.1.1`, from `release/2.1.0` (approved by Apple).

No behaviour changes: the same content, purchase and data. Version 2.1.1, build 30.

## What changed

1. **One chevron.** `RowChevron` (in `DesignSystem/AppComponents.swift`) replaces every typed "›" in list rows. The Fathers reader uses icon arrows in its footer.
2. **Read tab.** A bar under the Church Fathers card jumps to the Old Testament, Deuterocanon or New Testament. All 73 books stay in one list, so search, VoiceOver order and links do not change. At accessibility text sizes the bar stacks. Long book names shrink instead of breaking inside a word.
3. **Today.** The two progress rings show only after a reading plan starts or a chapter is read. A new reader sees no "0%".
4. **Settings.** The root keeps the library purchase, Reading and Translation (with the edition credit). Four rows open their own pages: Verse & Lock Screen (verse pool, a one-row rotation picker, numbered widget steps), Notifications, Reading Progress (and iCloud), Read Aloud, and About. At accessibility sizes the rows drop their decorative icons so words do not break.
5. **Fathers reader footer.** One line: section, then page. The translation credit moved to the bottom of the Contents sheet.
6. **iPad width.** Fathers pages are limited to 740 pt, like Settings. The Fathers reader keeps lines to about 680 pt on wide screens.
7. **Unlock page art.** Bloemaert's *The Four Evangelists* (already bundled, public domain) with its credit.
8. **App name.** The iPad sidebar says "John 1:1".
9. **Checked** in light and dark mode and at the largest accessibility text size on iPhone 17 Pro, and on the 13-inch iPad.

## Checks

- Core tests: 66 pass.
- UI tests run: FathersUnlock, WorksSettings, ReadingProgressB3c, SyncHandoffB4c, NativeSmoke. 35 pass, 3 skip (conditions that existed before: XXXL launch setting, release bundle, iCloud entitlement). WorksSettings, ReadingProgressB3c and SyncHandoffB4c were updated for the new Settings pages and the hidden rings.
- Not run this time: the other UI suites (AllRouteCapture, ContentFlow, ReaderParity and others).

## To ship (Anton)

1. Upload: `scripts/native/release-testflight.sh 2.1.1 30`.
2. Create version 2.1.1 in App Store Connect, attach build 30, add What's New, submit.
