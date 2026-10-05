# L09 source fixture review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: source expectations accepted. Native runtime parity is open.

Source commit `2429a8b` contains only the fixture generator and its README. The generator calls the current TypeScript parser and search service. Its adapters select the edition and load the source book manifest. Its database connection is read-only.

The output has 39 search requests and 19 reference requests across three editions. It records SQL and bound arguments. It covers all nine edition/scope pairs, numeric verse casts, reversed ranges, quoted phrases, result limits, correction after zero results, and no-match results. Reference cases cover fuzzy-name length boundaries and composed/decomposed accented text. Edit-distance probes preserve UTF-16 behavior.

Source reports two byte-identical runs. Generator SHA-256: `358f5de621abdfc1b27a794cfe2563884aa6031b350a365d5d75c88587807e1d`. README SHA-256: `726a3110c2f75c2b621eee6f1c5d4d9832ee28c20f18fbcc4aa5a252b97a03fe`. Output SHA-256: `698bdca2de158a03307ddf72f64dcb6e3a78b8167750781075c1aee531cef0e3`.

Keep the generated verse-text output in ignored evidence. Do not add it to the app bundle. The native comparison must use the same SQLite query order, correction candidate limit, and source vocabulary tie behavior. Main must run the parser and search actor through the simulator before L09 acceptance. Source can prepare that implementation outside active JohnCore while the storage probe runs.
