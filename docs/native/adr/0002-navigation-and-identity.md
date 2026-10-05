# ADR 0002: navigation and identity

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Status: ACCEPTED. L05 runtime acceptance remains open.

## Decision

Use typed tab, destination, modal, and passage-request values. Preserve the five-tab order: Today, Read, Saved, Pray, Settings. Search is a pushed destination. Closing Search restores the original screen. A Search result reuses Read and sends a new request.

Each passage request has a unique request ID. The same passage can therefore be requested again. An explicit requested edition takes precedence over the current preference. Saved items always send their stored edition. This corrects the source discrepancy recorded in `S00-source-discrepancies.md` and follows the approved rebuild plan.

Use exact edition IDs `web-ce`, `douay-rheims`, and `vulgate`. Keep source book codes. Verse labels are strings. Verse indices are zero-based chapter positions. Do not parse a bridge label as an integer.

Passage identity contains edition, book code, chapter, first label, and last label. Keep the exact legacy colon-separated database key. Selection also contains the validated indices and exact verse text. Heading text is not Scripture selection text.

Reader anchors contain verse label and UTF-16 offset. Works anchors contain section index, paragraph index, and UTF-16 offset. Native anchors survive width and typography changes. Legacy scroll and page positions are approximate hints until a native anchor is saved.

Validate external URLs at one boundary. Accept the existing `nrsv://read` and `nrsv://daily` parameter forms. Reject invalid coordinates and catalog IDs with a recoverable destination. Queue cold-start requests until state and repositories are ready. Consume each request once. Preserve request order.

## Evidence and limits

The source `dismissTo` behavior requires one existing Reader destination. Its library keys and source labels already contain edition identity. The initial layout port now preserves the source selection transition.

L05 must prove Search close/result return, repeated requests, saved-edition priority, invalid URLs, and cold-start delivery. L07 must prove actual anchors and hit testing. Their unobserved states remain open.
