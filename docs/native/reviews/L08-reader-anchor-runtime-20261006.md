# Reader anchor runtime review

Date: 6 October 2026. Reviewer: GPT-6.1 Sol.

The Build19 test passes in 57.718 seconds. Evidence is under `build/native-evidence/L08/reader-anchor-mask-01/`. Main integration is committed at `e0e1f73`.

The product and installed executable match at `7c17be280402dff7de529a77c2e8b080570f7f6a7d8d52de0a6a802f728b8fb4`. The debug library matches at `d5495661e33ca0e929f80529305afdfbd87eb1c4bdf3f7f71b27d196b791fce8`.

The test starts with WEB-CE, Medium, Comfortable, Serif, and paragraph layout. It scrolls to the lower controls without a selected verse. Previous and Next are hittable and end above the tab bar. The image shows both complete controls and the edition attribution.

Idle scrolling saves John 1, verse 50, UTF-16 offset 85. The test changes the committed size to Large. It keeps the anchor value and displays verse 50's continuation. It then terminates PID 56251 and launches PID 56599. The restart keeps the same anchor. The final revision-78 envelope contains `50:85` and Large.

The reflow and restart PNGs are byte-identical at `48e1c290ce8704d0bf20def7ee34c1a4cdd6b7917ff450897a95e18df939c50c`. The reviewer viewed both states and the lower-control image. The library hash stays unchanged.

This accepts anchor identity and visible verse restoration for this profile, plus lower-control reachability. It does not prove the exact offset's pixel position, width reflow, all typography settings, or all editions. The lower-scroll image has no text/status overlap. It does not isolate the top mask edge. Collect a short chapter-top image and a small-scroll clipping observation. Do not repeat the complete accepted journey.
