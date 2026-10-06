# L22 notification service source review

Date: 6 October 2026.
Reviewer: GPT-6.1 Sol.
Status: five source corrections required. Native runtime remains open.

## Reviewed boundary

Source owns `Platform/Notifications/NoticeCenter.swift` and `LocalNoticeService.swift`. Main owns Runtime, routes, lifecycle, delegate installation, target membership, and simulator control. The constructor and durable callbacks remain those in `L22-L24-platform-and-settings-handoff.md`.

Initial reviewed hashes:

| File | SHA-256 |
| --- | --- |
| NoticeCenter.swift | `0ef10acaecf7d525ef49f56d48ece4297f78fdcbc3af963c1315a09248a234c9` |
| LocalNoticeService.swift | `09220c4f7b2c5131be585297661c5dd811f7e66b0b4bf1e2de170767994a8995` |

The FIFO operation queue keeps saves, refresh, and permission reads in order across awaits. Each update reads committed state when its operation starts. An enabled user save can request alert and sound permission. A disabled save and refresh do not request permission. The service keeps an imported Rosary notification ID. It keeps unrelated requests outside its owned set. Calendar capacity, identifiers, titles, bodies, and URLs follow the source plan.

Runtime's committed-state callback rejects missing startup state and an uncertain durable save. Its commit callback throws when `applyWithResult` returns false. These boundaries are correct in source. They still need notification runtime evidence.

## Required corrections

1. When the system returns an unchanged repeating Rosary request, preserve it. Pending requests use `calendarComponents`; desired requests use `daily` or `weekly`. Enum equality currently fails for these equivalent triggers. Compare effective fields, repeat state, and time zone.
2. When a transaction fails, restore the complete original platform request. The current mapping loses non-string payload fields, custom sound, subtitle, category, and other notification content. Keep the original request for rollback. Keep the public service constructor unchanged.
3. After permission and catalog awaits, capture the current planning time and time zone. A permission prompt can remain open beyond today's delivery time. Do not plan from the time before the prompt.
4. During refresh, process both feature branches. A calendar coverage, capacity, or permission error must not prevent Rosary reconciliation or disabled-request cleanup. Keep the full refresh in one FIFO operation. Return both failures when necessary.
5. During rollback, report a failed pending-request query. Remove the unused first query. Do not replace a query failure silently with an empty list. Continue best-effort restoration and include the query error in `rollbackFailures`.

Source will send stable hashes after Swift 6 checks with and without DEBUG. Main's current target build started before these corrections. That product cannot accept notification runtime. Main will rebuild with the corrected hashes.

## Fixture evidence

The TypeScript generator executes the source services with bounded notification, storage, and clock stubs. Two current outputs match at SHA-256 `39e8d515223f940e826a6e772acfd6096055f104c332caced24d7c244d13ca2b`.

The new Toronto cases cover 02:30 during the spring transition and 01:30 during the repeated fall hour. The source produces `2026-03-08T07:30Z` and `2026-11-01T05:30Z`. Source reports matching Foundation component results. This is planning evidence. It does not prove system scheduling or delivery.

## Required runtime batch

Main will check enable, denial, time change, and disable for each feature. It will record actual pending request fields, unchanged-request preservation, imported Rosary ID behavior, unrelated request preservation, and concurrent refresh/save order. It will check partial scheduling failure and durable-save failure with rollback. It will also check one actual short DEBUG delivery and warm/cold response routing. Development delivery overrides must remain outside Release.

Reader spacing, Verse Moment export, and lifecycle integration can proceed in the same target batch. No accepted Gate A check needs another run.
