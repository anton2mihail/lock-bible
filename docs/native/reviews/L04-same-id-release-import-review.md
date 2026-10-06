# L04 same-ID Release import review

Date: 5 October 2026
Reviewer: GPT-6.1 Sol
Status: first launch accepted; restart and native-wins checks open

## Install sequence

Main restored the preserved old Release app over the earlier storage harness. It used bundle ID `com.nrsv.verse` without uninstalling. The old product declares native version `1.2.2 (15)`. The source JavaScript version is separately `1.5.0 (18)`.

Main did not launch the restored old app. Its install verification records schema 1, integrity `ok`, and an exact match for the original one bookmark, one gold highlight, and one note. Their identities, batch ID, text, and millisecond times remain unchanged. All five original database, WAL, SHM, MMKV data, and CRC hashes match. The consistent pre-install backup is 45,056 bytes and passes integrity check.

Main then installed native Release `1.5.0 (19)` with the same bundle ID and no uninstall. Its product executable SHA-256 is `0b731565808631d5b17b4631cf3b205ba33568650c5205e1265fa3dc6b4abfba`.

## First-launch acceptance

Sol reviewed these files in `build/native-evidence/L04/same-id-native-import-release-01/`:

- `old-release-install-verification.json`
- `native-import-first-launch.json`
- `product-hashes.txt`
- `native-release-info.txt`
- `old-app-info.txt`

Native process 55065 created format 1, revision 1, and importVersion 1. Its source hash marker matches the exact legacy MMKV files. It has no import issues. Typed state contains WEB-CE, medium/comfortable/serif/paragraphs, the imported Psalm 23 location, and the dismissed selection hint.

The first-launch report contains the exact original 1/1/1 rows. All five original file hashes still match the old-install report. The changed container UUID does not indicate data loss.

This first-launch scope is accepted. It proves the typed importer on the actual seeded same-ID simulator data. It does not yet prove a fresh-process restart or native-wins behavior.

## Remaining checks

1. Record the installed native Release executable hash against the product.
2. Inspect the app-created recovery backup. Check integrity, schema, exact rows, and its self-contained journal state.
3. Start a fresh native process. Check the committed envelope and retained original data.
4. Change a preference through native UI. Check the committed value and revision.
5. Restart in a fresh process. Check that native state wins over the unchanged legacy preference.
6. Record the matching scoped app integration commit.

SpringBoard denied the first restart command after termination. Main must preserve that error and inspect the specific process state. Do not uninstall the app or reset broad simulator services to obtain a passing result.

Gate A remains open. Signed App Group access, the full release fixture, physical-device update behavior, and final release readiness remain later requirements.
