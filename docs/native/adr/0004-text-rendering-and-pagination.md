# ADR 0004: text rendering and pagination

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Status: ACCEPTED mechanism. Production fidelity and full anchor checks remain open.

## Decision

Use a SwiftUI host with a UIKit attributed Scripture renderer. Keep pure source structure in JohnCore. Keep platform text measurement, hit testing, accessibility actions, and geometry in `Platform/TextRendering/`. Use public TextKit APIs and select the layout system explicitly.

The renderer takes immutable chapter layout, style, selected indices, saved highlights, and a passage request. It returns verse actions and validated text anchors. A typography change rebuilds attributed text and ranges. It does not change passage identity.

Preserve every source block separator and indentation kind. Keep pre-verse headings separate from inline headings. Heading offsets and verse ranges use UTF-16. Each text fragment retains its verse identity. A wrapped continuation tap resolves to that identity. Heading text does not trigger a verse action. Empty layout space does not select the nearest verse.

Active selection is an underline or outline. It preserves all four saved fills. Verse number line height equals passage line height. Registered font names, rounded base measurements, and one Dynamic Type scaling operation follow source tokens.

The production anchor records the visible verse label and within-verse UTF-16 offset. It must work when no verse is selected. Selection is independent of resume and context. A new request ID can reposition the same passage again.

Accessible verse actions call the same model action as a real tap. Heading and verse elements follow reading order. Keep selected state and heading semantics. The device speech check remains a release condition. A simulator element tree alone does not prove speech behavior.

Works retain pages. Use paragraph-aware page runs with original paragraph/UTF-16 ranges. Measure and render with the same width, font, and line height. Charge one source paragraph gap. A continuation at a new page has no extra gap. Include only complete line boxes when a viewport can fit them. A viewport smaller than a line must still terminate safely.

A Works style or width change restores the same text anchor. Page indices are hints. The repository loads one section. Do not decode unrelated sections or the full work for page layout.

## Evidence and limits

Sol reviewed the first proof sources and requested focused fixes for block breaks, width consistency, accessible actions, page fit, and paragraph gaps. The corrected selection reducer preserves the exact source range transition.

Sol inspected real WEB-CE John 1 flowing text with all four fills in `test-display-1.png`. The worker reports a real verse tap selected `web-ce:JHN:1:3`. Sol also inspected the corrected `03-works-page-2.png`. It shows a readable page that fits its viewport, reports 20 pages, and reports continuous source text with UTF-16 anchor 734. The earlier `02-works-page-1.png` had clipped text and is failed-fit evidence.

This evidence approves the UIKit/TextKit mechanism and paged Works direction. It does not approve the proof's final spacing or every anchor case. Real poetry/speaker comparison, the complete range sequence, wrapped continuation taps, live unselected anchor restoration, exact fonts/gaps, all text settings, and device speech remain L07/L08/L21 evidence. This ADR does not claim 1:1 parity from the prototype.
