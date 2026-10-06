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

At this review, app and widget code still use the literal `group.com.nrsv.verse`. The Debug entitlement uses the development group. Main must complete the shared configured App Group identifier before Debug widget continuity evidence. Release must keep the production group.
