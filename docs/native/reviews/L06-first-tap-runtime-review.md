# Reader first tap review

Date: 5 October 2026. Reviewer: GPT-6.1 Sol.
Verdict: changes required for the focused runtime check.

The Reader build passes in `build/native-evidence/L06/reader-build-03.log`. This result does not accept Reader parity.

The first UI run uses PID 29464. It opens John 1 and finds the first verse. The verse 10 tap does not produce a selected range. The result has two failed assertions. The current screenshot still needs export and visual review.

The second run uses PID 45572. It also fails at the verse 10 selection check. Its final accessibility tree shows the Saved root. Thus this run does not establish a text glyph hit failure. The synthesized point may be outside the visible Reader area even when the whole verse accessibility element reports `isHittable`.

Main must record the verse frame, clipped Reader viewport, screen tap point, and actual text hit result. Use a visible word inside that viewport. Check that the Reader root remains active immediately after the tap. Preserve paragraph blank-space behavior. Do not change a blank-space tap into a different verse selection to satisfy the test.

The Psalm 149 test must first scroll to and open chapter 149. It can then check that Back and Go To reveal and mark that current chapter. A first opening of the Psalms grid has no current chapter 149 to reveal.

The range test must assert actual selected labels and indices. Logged constants alone do not prove the selected range. Retain the expected five-tap reducer sequence and the Aa selection-retention check.

Run only the affected flow after the correction. Do not repeat accepted Gate A scenarios. Full verse-row geometry, matched chapter images, wrapped text, saved fills, anchors, and accessibility remain open.
