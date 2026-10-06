# L04 private read copy source review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: source and bounded repository runtime accepted. Same-ID production import remains open.

The fallback keeps the original library unchanged. It applies only after SQLite code 14 from a direct open or read inspection. The main file must be a nonempty regular file with WAL header bytes `0202`. No original WAL, SHM, or rollback journal can exist.

The code copies the stable main file to a unique private directory. It checks the source hash and sidecar set after the copy and before returning results. Only the copy changes to DELETE journal mode. The mode statement must finish and finalize. The checked close precedes private sidecar cleanup. The copy must have header bytes `0101` before read-only reopen. The boundary then checks schema, columns, counts, and integrity. Unsupported schema and damaged input remain errors.

The read handle owns the private directory. Repository reads check the source before and after each read. The actor handles a second connection created during an awaited call. It closes that redundant connection. Before a write, the repository requires a separate validated backup. It detaches the cached read handle before checked close. This prevents later use of a closed handle if cleanup fails. The write uses the original library.

The reviewed source hashes are:

| File | SHA-256 |
| --- | --- |
| `SQLitePrivateReadCopy.swift` | `771e3c27dc7bb6a317951d7dee701eba378741c3637a2e649f747bcf2e85b7e6` |
| `LibraryBoundary.swift` | `72fe817e8d3596f2036ceb028e185d57029948e074705c7c3bad13c5f96230d2` |
| `SQLiteLibraryRepository.swift` | `a6163bfd8c25fdacd85bfc361a68bf10c93136982b73e53090a10d4a6e2ccbce` |

The final repository runner is in commit `082661c`. Its SHA-256 is `2daba47ba8b6abc5161494fe9e4f2cd30ce694eb72b2c431170eac61024d0be3`. The earlier `ff9717ff` version is superseded. The final runner requires exact input hashes for the closed library, clean schema-77 file, and damaged file. It compares all 792 rotation rows and nine Bible chapter/passage fixtures. It checks read, note write, read again, exact pre-write backup rows, and private directory cleanup. Works checks cover real BLOB data, TEXT, damaged data, bounds, and missing rows.

Main owns the simulator run. All runner and probe APIs stay under DEBUG. Keep these source files fixed during the build. Runtime acceptance requires the exact error predicates, unchanged read inputs, matching installed binaries, a new process, and the recorded output paths. Commit the production fallback after that evidence passes. Same-ID typed import and startup UI checks remain separate Gate A requirements.

## Accepted simulator result

`build/native-evidence/L04/repository-runtime-01/repository-result.json` passes all nine checks. PID `46487` uses paths under its current process Documents folder. The closed source has schema 1 and row counts 2/1/1. Its hash and sidecar set remain unchanged after reads. Schema 77 returns the exact unsupported-schema error. Damaged input returns SQLite code 26. Both error inputs remain unchanged.

The note read, write, and read sequence returns the new note. A separate backup retains the exact original rows and note. The private directory is removed before writing and after repository release. All 792 rotation rows match in app and widget resources, including slot, index, boundary, and record fields. Nine Bible chapter/passage cases match. Real and synthetic Works checks pass, including BLOB, TEXT, damaged data, bounds, and missing rows. The runtime reports SQLite `3.51.0`, zlib `1.2.12`, and checked read-transaction close status `0`.

The installed app executable, app debug library, and widget debug library match the build product. Their hashes are `c89e87bc8d652748dab4c348cac277baafbaf7ff8637de92f4d826057934ff6f`, `8904b5477dca21d59f45540767d826979e73153d6b8b904089a4850014e6df84`, and `34953b6dd4a01635c62dfef15598441eb79537d51897117a7d60225118f83b97`. The evidence source hashes match the table above. This accepts the production fallback at those hashes. It does not close visual Reader, widget timeline, or full release update acceptance.
