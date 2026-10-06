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

## Visible tap checkpoint

UI04 places verse 10 inside the visible text area. The actual tap point is `(201, 169.7)`. Its observed selected labels are `[10]`. The next verse 12 tap at `(201, 289.7)` produces `[10, 11, 12]`. Sol accepts these two observed transitions as bounded evidence.

The next verse 8 is above the viewport. The helper swipes up repeatedly and moves it to approximately `y = -3497`. It then attempts an infinite coordinate after a failed visible-rectangle assertion. This is a test setup fault. Main must scroll toward the target and return without tapping if the clipped rectangle is absent or nonfinite. Check the remaining verse 8 taps in a short probe before a full setup replay.

UI03 also ended on Saved. It used `(201, 834.7)` because its Reader frame included the flat tab bar. The current helper clips above that bar. This correction produced the two successful UI04 text taps. No full Reader acceptance follows from this partial run.

## First image review

Sol viewed `reader-ui-04-attachments/006530A8-EEEB-4BDD-AFA4-4CF3E36FE5D9.png` against `L00/08-reader-john-1.png`. Both use light appearance and normal system text size. The current image includes the intentional missing-library status. It cannot establish the normal chapter's vertical spacing.

The first John paragraphs have the same visible body font and line breaks. The header still needs source corrections. Its horizontal 20-point padding is nested inside the outer 24-point padding. Remove that duplicate inset so the chapter title aligns with the text at 24 points. Back and the title chevron use the source text color. Aa and Search use the accent color. Use the staged `App/Artwork/icons/caretLeft` source PNG variants at 24 points for Back.

Show the exact selection hint when the committed `selectionHintDismissed` flag is false. Check its dismissal behavior with the full verse actions. Obtain a matched valid-library capture before normal visual acceptance. These changes do not block the short remaining range probe.

## Shared-line touch checkpoint

The short `reader-range-visible-01` run asserts the actual selected labels. Its first two taps match `[10]` and `[10, 11, 12]`. The next point targets the union accessibility frame for verse 8, but it selects verse 7. The later taps observe `[7, 8, 9, 10]`, then `[7]`, then no selection. The intended verse 8 sequence is not accepted.

Paragraph verses can share a line. Their union rectangles can include another verse's ink. Main must use an actual visible word owned by verse 8. Keep exact glyph ownership and blank-space rejection. Do not assign the whole union rectangle to a verse to satisfy the test.

The native accessibility element already overrides `accessibilityActivate()` and calls the exact verse index. A touch activation point can use owned visible glyph geometry. This is separate from VoiceOver activation and the selection reducer. Search and library data checks can proceed on the same binary.
