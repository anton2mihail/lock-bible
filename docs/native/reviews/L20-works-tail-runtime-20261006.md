# L20 Works tail runtime review

Date: 6 October 2026.
Reviewer: GPT-6.1 Sol.
Verdict: accepted for the recorded Homily 10 first-page journey. Full Works parity and Gate D remain open.

## Accepted bounds

`build/native-evidence/L20/card-works-batch-01/works-tail.log` records one passing method in 88.294 seconds. The stopped-app seed has no saved position for `chrysostom.homilies-on-the-gospel-of-john`. The method opens the real library and collection, opens Contents at section 1, scrolls the actual list, and selects Homily 10.

The method observes section 10, its exact text marker, page 1→2→1, and Previous/Contents/Next above the shared tabs. It changes Default/Medium to Large, returns to the same section text, closes the reader, and observes the Continue card. It terminates app PID96458, launches again, and opens that saved work through Continue. Homily 10 and page 1 are visible. It then restores Default/Medium.

The copied final envelope has revision 33. Its target-work fields retain `sectionIndex=9`, `pageIndex=0`, and anchor `{sectionIndex:9,paragraphIndex:0,utf16Offset:0}`. Sol checked these fields and the snapshot hash `2d6d5f67978bda52f3816ffbe7b24fcb88c1731972c8d55cf1106f1e991ea0d7`.

Sol also inspected the earlier preserved image `L20/works-aa-build-01/frames/works-final.png`, SHA `e06e7f680776936d50513dc240da8ae6ddb6b5e102f9b1beb8f4b56b9504ee83`. It shows Homily 10 page 1/21, paragraphs wrapped inside the 354-point text area, and the lower controls above the tabs. This image predates the tail run. The tail supplies the page, reflow, and visible-resume assertions.

## Provenance and limits

- Main's complete record: `L20/card-works-batch-01/run.txt`.
- Test source SHA: `d068967a59cde3f2e1b537a188ee2ce41987a5dd337765f8fbcb0858fb8e5de9`.
- WorkReader source SHA: `79a2265290b09f1329b8a2162f12a3261d17f4562ff814e7b3a5c2a714494203`.
- Device/runtime: iPhone 17 Pro, iOS 26.5, 354-point content width.
- Builder PID: 96322. Runner PID: 96382. XCTest records app PID96458 at termination. The initial and replacement app PIDs are unavailable in the record.
- Main records matching product/installed executable SHA `08276bba7ba376f67d1b62cb96221e3bf5a77db0e482df2ed1e7f988e1aaf662` and dylib SHA `77bf55787397689ed7d4eb989c9aac2e350b0095d2f70a37ed4a9a7240e40ce9`.

This accepts the observed wrap correction, Contents entry, page gestures, footer bounds, first-page size reflow, and first-page section resume. It does not prove a moved paragraph/UTF-16 anchor, middle-page restart, width-change restoration, every work kind, missing/error states, or matched old/native visuals. Do not repeat this complete method to check those remaining bounds.
