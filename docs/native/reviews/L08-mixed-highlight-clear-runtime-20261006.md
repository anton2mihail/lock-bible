# Mixed-highlight clear runtime review

Date: 6 October 2026.
Reviewer: GPT-6.1 Sol.
Verdict: accepted for the seeded two-verse range.

Evidence: `build/native-evidence/L20/mixed-clear-metric-02/`.

The stopped-app installed seed has integrity `ok`. It contains gold `web-ce:JHN:1:1` in batch `seed:1` and sage `web-ce:JHN:1:2` in batch `seed:2`. The test selects John1:1–2, taps Clear, and checks that all four highlight controls show `Not selected`. The method passes in 28.470 seconds. Runner PID is 15748. The app PID is unavailable; no PID is inferred.

Main stopped the app before the immediate final database copy. Sol read both copied databases in read-only mode. The final database has integrity `ok` and zero highlight rows. This closes the earlier seed-during-startup evidence gap for this range.

| Artifact | SHA-256 |
| --- | --- |
| Test source | `0a45d5af5325d04da7ab332fc77f5c463061da67c622d89b691c2ec7be94ba75` |
| Text renderer source | `fecdaf4b47d50369e217d75ec1c9f82cf51ffc895eff5c141fc11e17b5c7cd89` |
| Product and installed executable | `3ce06ddc08433b83ac227a5fa81233fa0b7afcf70be4546ff5eabf10dee52d08` |
| Product and installed debug dylib | `eda4e03e6e2f3647e3ff17000c10313c359e912348f4c664bf5d64da7f6ba918` |
| Installed-seed database copy | `a1eb76ac4e923d9d8252942e09a93a3ff30769aba852c1625dd60c98f0fc692b` |
| Final database copy | `12570cd7535e223f79d3f8cb0a6793d6dd8a64e91b683896c37b74ec356b257f` |
| Final native-state copy | `7c96b6091ce96add84b543a20daa227c73706aeb08a7e8bf086334c7ffe5875c` |

The profile is WEB-CE/Default/Comfortable/Serif/Verse by verse on iPhone 17 Pro, iOS 26.5. The observed verse2 point is frame-relative `(20,14)`, at screen `(44,260)` in this run. This result does not generalize that point to other fonts, editions, devices, or paragraph layout.

The run record identifies the setup data root as `4B7EE0C1-0B1F-4123-BF5F-9F524C85BB24`. The final manifest identifies `3594FC45-A58B-4A29-A03D-7A05426EC9CD`. Main must retain the stage-specific path explanation in the record. No new run is required for that metadata correction. Visual fill parity, other range transitions, and action failure states remain open.
