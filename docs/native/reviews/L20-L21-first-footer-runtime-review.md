# First Works footer runtime review

Date: 6 October 2026.
Owner: GPT-6.1 Sol.
Status: Bounded behavior observed. Matching runtime hash report is pending. Full Works acceptance remains open.

The `L22/anchor-today-works-share-02.log` records `testWorksReaderFooter` passing in 16.095 seconds. It enters through Read, opens Augustine, and opens `augustine.our-lord-s-sermon-on-the-mount`. The test finds real prose, a hittable Next section button, and a button frame above the shared Saved tab. It checks section 1, taps Next section, and checks section 2. This proves the observed route and footer behavior. It does not prove complete text pagination, reflow, exit writes, resume, or source-matched visual parity.

The same run reaches Verse Moment and opens Reader with title `2 Timothy 2` and the WEB-CE attribution. Its old title selector fails. The current route assertions accept any Reader title and any verse. Main must compare the displayed Verse Moment reference with the Reader book, chapter, and visible requested context in the next corrected selector run.

The PNG test reaches export but fails its `app.sheets` lookup. Sol inspected the resulting 1080 by 1440 ivory card for 2 Timothy 2:23. It has complete readable quote text, the reference, WEB-CE, wordmark, and artwork. This is bounded successful export evidence. It does not prove share-sheet action selection, both backgrounds, long-text height, preview agreement, repeated export, or temporary-file cleanup. Keep the failed selector result separate from the successful file result.

Main owns result preservation, installed/product hash comparison, UI hierarchy inspection, and the next focused runtime checks. Do not repeat the accepted Saved or Gate A journeys for this batch.

## Run 03 checkpoint

The Verse Moment route test passes in 13.423 seconds after the title-selector correction. This accepts bounded route entry only. Its assertions still permit any Reader title and verse. Exact displayed-reference and visible-context agreement remain open.

The Works rerun starts from its saved section after the first test changed position. `WorksCollectionView` passes no explicit section. `WorkReaderView` then reads the committed section index. The hardcoded section 1 and 2 checks are invalid on this resumed fixture. Keep the earlier footer and Next-section pass. Do not change resume behavior to satisfy the test.

The share rerun fails the Copy-action lookup. Separate URL and Boolean presentation state can permit a stale sheet payload. This is a source hypothesis until Main supplies the actual failure hierarchy and screenshot. A native share sheet need not appear under `app.sheets`. Keep the proven PNG export separate from presentation acceptance.
