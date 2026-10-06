# L09 source fixture review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: source expectations accepted. Native runtime parity is open.

Source commit `2429a8b` contains only the fixture generator and its README. The generator calls the current TypeScript parser and search service. Its adapters select the edition and load the source book manifest. Its database connection is read-only.

The output has 39 search requests and 19 reference requests across three editions. It records SQL and bound arguments. It covers all nine edition/scope pairs, numeric verse casts, reversed ranges, quoted phrases, result limits, correction after zero results, and no-match results. Reference cases cover fuzzy-name length boundaries and composed/decomposed accented text. Edit-distance probes preserve UTF-16 behavior.

Source reports two byte-identical runs. Generator SHA-256: `358f5de621abdfc1b27a794cfe2563884aa6031b350a365d5d75c88587807e1d`. README SHA-256: `726a3110c2f75c2b621eee6f1c5d4d9832ee28c20f18fbcc4aa5a252b97a03fe`. Output SHA-256: `698bdca2de158a03307ddf72f64dcb6e3a78b8167750781075c1aee531cef0e3`.

The reviewed draft used reference-name normalization for text-search tokens. That removed periods and joined separate words. The source search service keeps periods as token boundaries. The corrected draft now keeps these normalization paths separate. Two added source cases confirm `faith.hope` produces `"faith"* AND "hope"*`, and `"In.the beginning"` produces `"in the beginning"`. The fixture now has 41 search requests. Its SHA-256 is `a1c1756da340da6c2c40aee2226b6a1644699cd724dc3de5bbff402f86bd0f30`. Generator SHA-256 is `9213112d09edd9f3ed0a988884d04427d2dd0a6da6306957cd9fa42e93abf950`. The draft Search source hash is `e42d1cc0308ecfe1973a296a45a8332b079d3944f03b138e189caf22daac4a65`. These source additions are accepted. The host comparison attempt stopped on an index-store access error. It does not prove the updated native comparison. Main must compare all 41 requests on the simulator.

Keep the generated verse-text output in ignored evidence. Do not add it to the app bundle. The native comparison must use the same SQLite query order, correction candidate limit, and source vocabulary tie behavior. Main must run the parser and search actor through the simulator before L09 acceptance. Source can prepare that implementation outside active JohnCore while the storage probe runs.
