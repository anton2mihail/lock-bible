# Remaining gate runtime order

Date: 6 October 2026.
Reviewer: GPT-6.1 Sol.
Status: implementation and simulator checks continue. Gates B through E remain open.

Main owns every simulator operation. Source owns isolated source files, fixture preparation, and source fixes. Use one coherent build for each completed source batch. Keep product, installed binary, input, process, and result evidence together. Do not repeat an accepted check without a relevant code change or a specific fault.

## Next simulator batches

1. Finish the current Verse Moment, Scripture card, Reader lower-control, and Works footer checks. Record exact verse/edition and next-section identity. For PNG export, inspect actual width, complete measured height, both backgrounds, long text, and temporary-file cleanup. A visible share sheet alone does not prove the PNG.
2. Finish Reader and Aa. Use valid-library John, Psalm, and Song captures at matched settings. Check owned visible verse text for the remaining selection transitions. Check saved fill with selection, verse layout, Go to, previous/next, all editions, and unselected anchor restoration after typography/width change. Check new note creation, all highlight colors, copy/share, and a non-WEB saved item's original edition. Keep the accepted existing-note and Undo flow out of this batch.
3. Check the remaining Search UI behavior and widgets. Use a reference, phrase, correction, Latin query, scope/edition change, rapid typing, close/return, and the same result twice. The repository comparisons already pass. For widgets, check all three kinds, supported families, actual timeline fields, preference projection/reload, links, midnight/year fallback, and app/widget agreement. Record which installed-widget behavior the simulator can prove.
4. Check content persistence and temporary state in one route journey. Check known daily/Sunday dates, Joel/Esther context, finite coverage, and Today before/after 17:00. Favorite a prayer. Save Sunday reflections and novena intention/completion, then restart once and inspect their exact keys. Check teaching links, all Rosary catalog sets, distinct Seven Sorrows, back/completion/reset, Lectio's quiet minute, and Confession clearing on exit/inactive/finish. Use the source fixtures for exact values. Include invalid IDs and missing-citation fallback.
5. Check Works and complete Settings. Open library/collection/commentary, a real long section, contents, page/section controls, style/width reflow, and saved-anchor restart. Check the lower controls above the tab bar. Check Settings/Aa agreement, each reading control, translation attribution, scope, cadence, installed coverage, credits, and notification entry/return. Counts and catalog order must match source.
6. Check notices and media on the corrected target. Check both notice features' enable/deny/change/disable states, pending fields, imported ID, unrelated/unchanged request preservation, serialized save/refresh, and rollback. Use the real OS clock for short DEBUG delivery and cold/warm tap. Check media mode/episode/exit/inactive cleanup and failure state. Check Release with no sample player/URLs and all six official links.

Batches can share one running app and synthetic fixture when actions do not invalidate the next starting state. Use a fresh task-only seed when a changed database would make an expected value ambiguous. No unit-test suite or new prototype is required.

## Shared integration gaps

`ReaderLocation.anchor` and app capture/restore are implemented. Older records still decode without an anchor. The source rejects invalid decoded anchors and negative scroll offsets. Capture uses chapter/request identity and suppresses writes during restoration. Actual unselected-anchor restoration after restart, typography change, and width change remains open. Legacy raw offsets remain fallback values. Do not change paragraph blank-space hit behavior for a test.

Today and Calendar now use the shared feature clock and time zone. DEBUG arguments can supply a fixed date and zone. Today rotation receives those same inputs. The exact Verse Moment route passed with 2 Timothy 2:23 and WEB-CE. Date-boundary content checks remain open. Notification delivery uses the actual OS clock. An injected app date proves planning only.

The corrected notification service must preserve an unchanged system trigger and the complete original request during rollback. Main's committed reader rejects absent or uncertain state. Main retains one active-hour refresh task, startup/foreground/significant-time/time-zone refresh, and validated response routing. See `L22-notification-service-source-review.md`.

The app and widget now read their build-configured `AppGroupIdentifier`. Both built Debug property lists resolve to `group.com.nrsv.verse.dev`. Release keeps the original production group. Effective signed container access and installed-widget continuity remain open.

## Final gates

| Scope | Required work after feature checks |
| --- | --- |
| L25 | Capture old/native pairs for all 29 routes and relevant states. Keep date, edition, saved state, typography, device, appearance, and status bar matched. Complete dark, largest text, small iPhone, iPad, keyboard, accessibility tree/focus, and Reduce Motion checks. Record each approved accessibility divergence. |
| L26 | Use a Release simulator build with networking unavailable. Measure cold useful-content launch, chapter/query latency, long text scroll/page behavior, memory, installed size, and actual extension resource use. Report median/tail samples and toolchain/device. Provisional physical-device budgets are not simulator measurements. Fix measured faults. Keep full Bible/Works decode out of startup. |
| L27 | Rehearse a full same-ID Release update without uninstalling. Seed all persistent categories: multiple-edition library rows, overlap batches, novena intentions/completion, favorites, Sunday reflections, Reader/Works positions, appearance, reminder settings/IDs, and widget preferences/configurations. Check first import, native-wins restart, repeat update, and affected interruption boundaries. The accepted small Gate A import is not the complete release fixture. |
| Gate E | Review all-route/content/visual evidence, offline behavior, complete update preservation, and accepted exceptions. No route or placeholder flow can remain missing. |
| L28 | Build a reproducible archive. Inspect signed app/extension IDs, App Group, URL scheme, deployment floor, bundled licenses/privacy declarations, Debug exclusions, media gate, and icon/launch resources. Capture current store screenshots and release instructions. Do not submit or publish. |
| S02 | Record final readiness and any external limits. The plan still requires limited physical-device evidence for actual VoiceOver speech, signed installed-widget continuity, notification delivery/tapping, lifecycle clearing, and native sharing where the simulator cannot prove behavior. Do not claim these checks from simulator images. |

Keep the deployment-floor iOS 26.0 check separate from the current pinned iOS 26.5 runtime. Complete it before release readiness. If a required runtime or signing resource is unavailable, state the exact missing evidence and continue independent simulator work.
