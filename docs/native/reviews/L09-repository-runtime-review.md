# Search repository runtime acceptance

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Verdict: repository and parser comparison accepted. Full L09 UI remains open.

Main ran the committed Search repository on the iPhone 17 Pro iOS 26.5 simulator. PID `98952` logged its current bundle, home, and in-container fixture/output paths. The installed executable and dylib hashes match the build product. The build-for-testing log reports success.

The source fixture hash is `2b489648b2c454b624d5d43e5cdb431b0bee04fc30ef66b6a76ff23e8c5d2a6b`. The comparator hash is `ce2527182b9ad9cd3236f80ee480dede983dda34562301ebf7c4a2247444a7cb`. Sol also read the installed app's search database hash. It matches `e2ee48c4edaeeaa5c6b340af35e32b228563c3191ca55453340dfd9b8fe1fd94`.

`build/native-evidence/L09/simulator-01/output.json` has no mismatches. It matches all 41 searches, 57 edition-specific parsed results, four normalization probes, three UTF-16 distance probes, and six FTS query probes. The output hash is `255cdad9b3466bfdf84682dee8ed07df45caba1e99f5a5d5d2de301362469b45`.

This accepts the bounded runtime comparison for commit `88ec254`. Full Search UI still needs result rendering, correction feedback, scopes, debounce, cancellation, stale-result rejection, and navigation evidence. It also needs matched old/native screen captures. Gate B remains open.
