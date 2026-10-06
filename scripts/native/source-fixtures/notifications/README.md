# Notification source fixtures

This generator runs the current TypeScript calendar and Rosary reminder services. It does not reimplement their planning rules. It replaces storage, Expo notifications, and the clock with bounded in-memory stubs. It does not call an operating-system notification API.

Run it from the repository root:

```sh
bun scripts/native/source-fixtures/notifications/notice-fixtures.ts \
  build/native-evidence/L22/source-notifications.json
```

The output records source hashes, calendar coverage, delivery-time boundaries in Toronto and UTC, spring and fall time-zone changes, the 0–30 day plan, installed-data fallback text, no-plan and capacity errors, and request reconciliation. It records Rosary normalization, daily and weekly triggers, weekday 2, legacy request replacement, disable behavior, and source permission denial.

Rosary permission denial has a source-specific result. The TypeScript service cancels its stored request, writes disabled settings, and then throws. The output keeps this behavior separate from the native serialized and durable-save contract.

The source fixture does not prove native behavior. Main can use the generated request fields as expected values for its native service comparison. Keep output under ignored `build/native-evidence/`.

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
