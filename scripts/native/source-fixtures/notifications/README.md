# Notification source fixtures

This generator runs the current TypeScript calendar and Rosary reminder services. It does not reimplement their planning rules. It replaces storage, Expo notifications, and the clock with bounded in-memory stubs. It does not call an operating-system notification API.

Run it from the repository root:

```sh
bun scripts/native/source-fixtures/notifications/notice-fixtures.ts \
  build/native-evidence/L22/source-notifications.json
```

The output records source hashes, calendar coverage, delivery-time boundaries in Toronto and UTC, spring and fall time-zone changes, and the 0–30 day plan. It includes 02:30 on the Toronto spring transition and 01:30 on the fall repeated hour. It records installed-data fallback text, no-plan and capacity errors, and request reconciliation. It records Rosary normalization, daily and weekly triggers, weekday 2, legacy request replacement, disable behavior, and source permission denial.

Rosary permission denial has a source-specific result. The TypeScript service cancels its stored request, writes disabled settings, and then throws. The output keeps this behavior separate from the native serialized and durable-save contract.

The source fixture does not prove native behavior. Main can use the generated request fields as expected values for its native service comparison. Keep output under ignored `build/native-evidence/`.

## Native service comparison handoff

`L22ServiceComparison.swift` is a DEBUG-only helper for the production `LocalNoticeService`. Main must add it to the app target and call `L22ServiceComparison.run(sourceFixtureURL:readCalendars:)` after it supplies a fresh copied fixture and the shared calendar repository closure. The helper does not create another planner and does not call `UNUserNotificationCenter`.

The report has exactly 25 observations. It compares all 14 source calendar plans. It compares exact identifiers, titles, bodies, URLs, and epoch-millisecond delivery times. It also checks unchanged daily/weekly system component requests, imported Rosary IDs, unrelated request preservation, 62 unrelated requests at capacity, a permission delay across today's delivery time, commit-failure restoration, partial calendar-add rollback, rollback query failure reporting, independent Rosary cleanup after a Calendar error, permission-denial state preservation, and FIFO order across two saves and refresh. `passed` is true only when all 25 observations pass.

The partial-add check fails the second calendar add. It requires the first added request to be removed, the pending list to match its initial empty state, and committed settings to remain unchanged. The denial check starts with two unrelated pending requests and non-empty committed state. It requires no commit call and exact state preservation. The FIFO check starts from enabled Calendar and Rosary settings. It records invocation order, committed-state reads, commits, and pending-query start/end events. It requires the first save to commit before the next state read, the second save to commit before the refresh state read, and all three operations to run in invocation order. It also requires no overlapping pending queries.

The fake center proves that the service calls `restore` with the complete original `NoticeRequest` value. It does not prove that `UNNotificationRequest` custom sound, subtitle, category, typed userInfo, or other platform fields survive the system-center round trip. Main must check those fields with the real system adapter. The helper also does not prove delivered notifications or tap routing. The source's Rosary permission-denial reset remains a separate fixture behavior; the native service follows its durable rollback contract.

To compare two fresh outputs and record their hashes:

```sh
bun scripts/native/source-fixtures/notifications/notice-fixtures.ts \
  build/native-evidence/L22/source-notifications-a.json
bun scripts/native/source-fixtures/notifications/notice-fixtures.ts \
  build/native-evidence/L22/source-notifications-b.json
shasum -a 256 build/native-evidence/L22/source-notifications-a.json \
  build/native-evidence/L22/source-notifications-b.json
cmp build/native-evidence/L22/source-notifications-a.json \
  build/native-evidence/L22/source-notifications-b.json
```
