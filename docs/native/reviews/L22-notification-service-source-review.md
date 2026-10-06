# L22 notification service source review

Date: 6 October 2026.
Reviewer: GPT-6.1 Sol.
Status: corrected source accepted for target build at `6e87cfa`. Native runtime remains open.

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

## Corrected source decision

All five fixes are present. The system center retains the complete immutable `UNNotificationRequest` and restores that snapshot. Rosary trigger comparison uses effective components, repeat state, and time zone. Planning captures the clock after permission/catalog awaits. Refresh attempts both branches and reports their failures. Rollback reports a failed pending query and continues restoration.

One final source finding was corrected before acceptance. A weekly request with a specific day, month, or year cannot count as an unchanged weekly reminder. The comparison rejects these restrictions. Effective time zone uses the component zone, then its calendar zone, then the current zone.

| Accepted file | SHA-256 |
| --- | --- |
| NoticeCenter.swift | `8e206090c86bc07f4357fb17b61dfa3b64778d2e711312c3fca0d22e9ecb5d7d` |
| LocalNoticeService.swift | `185aea8d6348ad928f24438ed4fe0c4b16ae06159a3c8fbb93f4cde364500582` |

Sol checked the final files and hashes. Source reports passing Swift 6 arm64 simulator SDK checks with and without DEBUG. Implementation commit `6e87cface8e96d886cd00b4fc24b6fc6f1ff5cd5` contains only these two files. This accepts source inclusion. The runtime batch below remains required.

## Fixture evidence

The TypeScript generator executes the source services with bounded notification, storage, and clock stubs. Two current outputs match at SHA-256 `39e8d515223f940e826a6e772acfd6096055f104c332caced24d7c244d13ca2b`.

The new Toronto cases cover 02:30 during the spring transition and 01:30 during the repeated fall hour. The source produces `2026-03-08T07:30Z` and `2026-11-01T05:30Z`. Source reports matching Foundation component results. This is planning evidence. It does not prove system scheduling or delivery.

## Required runtime batch

Main will check enable, denial, time change, and disable for each feature. It will record actual pending request fields, unchanged-request preservation, imported Rosary ID behavior, unrelated request preservation, and concurrent refresh/save order. It will check partial scheduling failure and durable-save failure with rollback. It will also check one actual short DEBUG delivery and warm/cold response routing. Development delivery overrides must remain outside Release.

Reader spacing, Verse Moment export, and lifecycle integration can proceed in the same target batch. No accepted Gate A check needs another run.

## Simulator comparison source

The DEBUG-only comparison helper is accepted at `3e909b15a1c2f715b15a8e35845f8f1d02c32a49`. Its SHA-256 is `d2bce2498efcd9a034157fd58bb4997925c709ca8f14fe479daaa538a7b03762`. The report requires exactly 25 passing observations. It compares 14 source calendar plans and 11 native service contracts.

The corrected FIFO predicate checks ordered reads, the first pending-query completion before read 2, and each save commit before the next read. Partial-add failure checks exact initial pending/state preservation and zero commits. Denial checks two retained requests, nonempty committed state, and zero commits. This accepts helper source only. Main must run it inside the simulator with the exact fixture hash above. An injected center does not prove actual system permission, delivery, or full request round-trip preservation.

Current Runtime integration uses the real clock and auto-updating zone. Its committed reader rejects uncertain state. Startup, foreground, active-hour, significant-time, and time-zone events request service refresh. The app delegate validates Daily and Rosary response routes and queues responses received before startup. These source boundaries are suitable for the next runtime batch. Their actual lifecycle and tap results remain open.
