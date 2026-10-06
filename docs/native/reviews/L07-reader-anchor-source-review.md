# Reader anchor source review

Date: 6 October 2026.
Owner: GPT-6.1 Sol.
Status: Core field accepted with the decode correction. App capture and restore remain open.

## Core field

Commit `752e60db74d00bfac1b92edb705cb8fef72e9644` adds optional `ReaderLocation.anchor`. Old records can omit the field. A null field also decodes. Missing `updatedAt` decodes as zero. The location initializer rejects an empty verse label and a negative UTF-16 offset. The existing `setReaderLocation` command writes the complete location. No state envelope version change is required.

The first custom decoder passed a negative saved `scrollY` through the clamping initializer. That changed the prior damaged-envelope behavior. Source corrected this regression. The decoder now rejects a negative saved offset before it calls the initializer. The public initializer keeps its existing normalization. The corrected working Domain hash is `44f9f11b0be9d5a3b85a5440fc51a7ebf840692c78612d1a5a16950f0840e343`. This hash also includes the separate existing `WorkSectionSummary` hunk. Do not include that hunk in the decoder commit.

Source reports passing host and arm64 iOS Simulator SDK builds for the field. These builds do not prove app capture or restore.

## App findings

The TextKit body-range capture does not depend on selected verse indices. The model checks the active chapter request before a location save. These are suitable boundaries.

Main must correct these concrete defects before app acceptance:

1. Deferred restore callbacks can scroll a later chapter. Include the chapter request identity in each restore and reflow request. Check it before any scroll. Capture a reflow anchor only from the same TextKit chapter.
2. The view clears the pending restore immediately after `scrollTo`. An idle callback can then save during the programmatic scroll. A saved anchor with zero raw offset also bypasses the current offset guard. Use explicit restore state for initial and reflow scrolls. Suppress capture and writes until the matching scroll completes.
3. Anchor capture chooses the smallest line Y from dictionary iteration. When two verses share a line, this can choose either verse. Use a stable order by line Y, owned text X, and source range or verse index.
4. The render signature omits width. A text-container width change can reflow without anchor restoration. Include width changes in the reflow mechanism.

Keep blank-space hit behavior unchanged. Check an unselected anchor, Aa reflow, a width change, a chapter change before a deferred callback, and restart restoration in the next coherent simulator batch. Record the source and installed product hashes. Full Reader visual and accessibility acceptance remain open.

## Shared configuration

At the initial review, app and widget code used the literal `group.com.nrsv.verse`. The Debug entitlement uses the development group. Main has now added `AppGroupIdentifier` to both Info plists. The project generator sets `APP_GROUP_IDENTIFIER` to `group.com.nrsv.verse.dev` in Debug and `group.com.nrsv.verse` in Release. Both code paths read the Info value. This closes the source configuration finding. Effective signed group access and widget preference agreement remain runtime evidence.

## Follow-up source checkpoint

Source committed the negative decoded-offset guard alone at `58e7c0b764a8d98b56e5445a39c912c639313b90`.

Main has added chapter request identity to restore requests, same-chapter reflow guards, explicit programmatic restore state, stable candidate ordering, and width reflow capture in `sizeThatFits`. These changes address the original boundaries. The follow-up review found two final corrections: remove the old duplicate `best` declaration; and close the pending-anchor capture guards, no-target completion, and raw-offset task identity check across `Task.yield`. Main received these requests before the coherent Works/share build. They do not block independent feature evidence after the corrected target builds. Reader runtime acceptance remains open.

Main's coherent build 04 passes. The stable source includes the four mechanisms and both final corrections. One deferred-capture guard must also run inside its `Task`, because a restore can begin after the outer closure check. Main received this small follow-up for the next source boundary. The built app and widget resolve the development App Group. This verifies configuration substitution, not signed shared-container access.

The `anchor-works-share-01` test run fails before navigation. Both tests cannot find the Today action with label `Verse & lock screen widget`. The log records app PIDs 88568 and 88781. These failures do not exercise Works, its footer, PNG export, or anchor restoration. Main must inspect the failure hierarchy and screenshot before a focused rerun. Preserve this result as failed entry evidence.
# Reader runtime checkpoint: safearea-02

Date: 6 October 2026.
The `reader-anchor-safearea-02` run measures a 62-point key-window top safe area. Its ScrollView accessibility frame starts at zero. Sol inspected `reader-anchor-safearea-02-attachments/99131180-8153-4C6F-82DA-84BF7E03BC01.png`. Scripture lines visibly overlap the status icons. This confirms a top drawing defect. AX geometry alone was not the verdict. Main must contain and clip the viewport at the measured safe-area boundary, without a fixed status-bar height or duplicate content padding.

The same image shows verses 39–47 after five swipes. The saved anchor still reports verse 1, offset 0. This run proves scrolling but does not prove correct anchor capture. Capture and reflow currently use `max(0, -scriptureOriginY)`. Main must check the actual scroll offset, Scripture origin, converted local viewport top, and returned anchor. Keep one coordinate boundary for capture and restore. Keep chapter/request guards and write suppression during restoration.

The footer remains below the viewport in this image. Five swipes did not reach the content end. The later test uses a removed Settings picker identifier. Use the always-visible Settings tab and its current direct size controls. Auto-scrolling to the Reader Aa header would first move the visible anchor. Check Aa agreement separately. Choose a size different from the current value and require a non-initial moved anchor. Stored-anchor equality and a verse union-frame intersection alone do not prove restoration of the saved within-verse UTF-16 offset. Observe its owned line or restore target inside the measured viewport. No Reader runtime acceptance is added by this failed run.

## UIKit coordinate boundary

Later traces show a scroll offset of about 5466 points while both SwiftUI global geometry values remain zero. These values cannot supply the visible TextKit coordinate. The actual Settings size tap committed `large` at native revision 86. Its missing accessibility selected state is a separate fault.

Use the actual `ReaderTextKitView` and its enclosing ancestor `UIScrollView` for coordinate conversion. Convert the visible scroll bounds into TextKit coordinates. Apply the window safe-area and clipping intersection once. Skip a capture when this viewport is absent or invalid. Do not replace it with local coordinate zero. Idle capture, pre-reflow capture, width reflow, context positioning, and anchor restoration must use this same boundary. Obtain the pre-reflow measurement before replacing the old layout. Keep existing chapter/request guards and programmatic-write suppression.

Main owns this implementation. First prove one non-initial anchor from one actual scroll. Then collect the top clipping image and the reflow/restart result. The UIKit source boundary does not accept runtime anchor restoration or full Reader parity.

## Run 09 result

The UIKit change captures a non-initial anchor at `48:44`. The corrected Settings choice exposes its leaf identifier and `Selected` value. The test changes the current size and reaches both reflow and restart checks. Both visible-anchor checks fail.

Sol inspected all three images in `build/native-evidence/L22/reader-anchor-safearea-09-attachments/`. `1B79D034-8FDE-418A-8F04-9E3409EB8C4E.png` shows both Previous and Next fully above the tabs. Scripture still draws behind the status icons. `EA934873-E2D0-4EF2-AA0E-B8AAB3959260.png` shows verses 15–22 after reflow. `0130B5A5-92A1-4119-8873-D1988B953622.png` shows the chapter header and verse 1 after restart. These images do not prove anchor restoration.

The source consumes a restore request before it proves view attachment and layout. It also clears the pending anchor when coordinate measurement fails. Keep that request pending until current geometry permits the restore. Issue the target after the enclosing scroll content has its final extent. Verify the actual restored glyph against the measured viewport. The top overlay uses the SwiftUI parent coordinate space and does not protect the actual status area in these images. Main must correct the actual viewport boundary.

The lower-control image is bounded geometry evidence. Keep matching installed/product/process records with it before final route acceptance. Do not repeat the accepted notification comparison while these Reader fixes proceed.
