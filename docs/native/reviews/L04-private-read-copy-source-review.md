# L04 private read copy source review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: source accepted for the bounded simulator run. Runtime acceptance remains open.

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
