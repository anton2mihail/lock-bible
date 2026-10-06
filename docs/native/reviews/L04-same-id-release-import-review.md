# L04 same-ID Release import review

Date: 5 October 2026
Reviewer: GPT-6.1 Sol
Status: bounded Release import and native-wins runtime accepted

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

## Restart and native-wins acceptance

Sol reviewed `native-import-restart-01.json`, `native-wins-restart-result.json`, the UI test source, and `native-wins-ui-test.log`. The first restart report uses PID 58449 and retains revision 1, the complete typed state, exact original rows, and all five file hashes.

The UI test targets `com.nrsv.verse`. It changes Settings from imported Medium to Large. It terminates PID 68968 and launches the same Release app again. Settings then reads Large. The test passes in 22.322 seconds with zero failures. The final process is PID 69399.

The final envelope has revision 2, importVersion 1, and Large text size. Its unrelated state fields and original import hashes remain unchanged. The original legacy MMKV files still contain the imported source bytes. The original DB, WAL, SHM, data, and CRC hashes remain unchanged. The complete bookmark, highlight, and note rows match the first-launch report.

The installed Release executable matches the product SHA-256 above. The app-created recovery backup is 45,056 bytes. Its schema is 1, integrity is `ok`, and its exact 1/1/1 rows match the original library. Its SHA-256 is `db7ce346df38cab53fa7101f6844023e2dd56fe1e327e1925b1bba77eedc7522`.

This bounded same-ID Release runtime is accepted. Main must add the final process and backup journal records to its report. No repeat app run is required for this record.

## Final handoff

Main attached `run.txt` with the exact PID sequence. `native-recovery-backup-summary.json` confirms DELETE journal mode, header bytes 1/1, no WAL/SHM/journal sidecars, schema 1, integrity `ok`, and exact rows. Main committed the coherent app integration at `df8cc9b85595a8be24709d8692de62a45410f293`. Its Reader foundation files retain separate open L06–L08 verdicts.

SpringBoard denied the first restart command after termination. Main preserved that failure. The later restart and UI test pass. This failed command does not negate the later observed fresh processes.

Gate A is accepted for its foundation scope. Signed App Group access, the full release fixture, physical-device update behavior, and final release readiness remain later requirements.
