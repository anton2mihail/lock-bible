# Reader anchor runtime review

Date: 6 October 2026. Reviewer: GPT-6.1 Sol.

The Build19 test passes in 57.718 seconds. Evidence is under `build/native-evidence/L08/reader-anchor-mask-01/`. Main integration is committed at `e0e1f73`.

The product and installed executable match at `7c17be280402dff7de529a77c2e8b080570f7f6a7d8d52de0a6a802f728b8fb4`. The debug library matches at `d5495661e33ca0e929f80529305afdfbd87eb1c4bdf3f7f71b27d196b791fce8`.

The test starts with WEB-CE, Medium, Comfortable, Serif, and paragraph layout. It scrolls to the lower controls without a selected verse. Previous and Next are hittable and end above the tab bar. The image shows both complete controls and the edition attribution.

Idle scrolling saves John 1, verse 50, UTF-16 offset 85. The test changes the committed size to Large. It keeps the anchor value and displays verse 50's continuation. It then terminates PID 56251 and launches PID 56599. The restart keeps the same anchor. The final revision-78 envelope contains `50:85` and Large.

The reflow and restart PNGs are byte-identical at `48e1c290ce8704d0bf20def7ee34c1a4cdd6b7917ff450897a95e18df939c50c`. The reviewer viewed both states and the lower-control image. The library hash stays unchanged.

This accepts anchor identity and visible verse restoration for this profile, plus lower-control reachability. It does not prove the exact offset's pixel position, width reflow, all typography settings, or all editions. The lower-scroll image has no text/status overlap. It does not isolate the top mask edge. Collect a short chapter-top image and a small-scroll clipping observation. Do not repeat the complete accepted journey.

## Later chapter-top check: Build21

The later check accepts the removal of the duplicate mask inset. The reviewer viewed both images in `L08/reader-top-edge-02-attachments/`. At natural chapter entry, the full Back/Aa/Search row, John 1 title, and selection hint appear below the status area. After the short drag, the header scrolls with the chapter and the status area stays clear. The images do not isolate Scripture ink at the exact 62-point boundary.

The executable matches the installed app at `8bd5c3abe2ad14820d53b6e0108e5f96a8f6a47217553d94d76e292ceae2e895`. The debug library matches at `43e7ee93f576836216a0f6526345657b886e0dc246ff4f34e86dbc063aa17ce2`. App PID is 63247; test runner PID is 63203. ReaderView source hash is `7b9eef52a1ec7fb5f88795fc439978d634d976eefeccd780f491d8409f0ee6c5`.

The test reports a failure at its `frame.minY` string predicate. Its final frame log records verse 1 moving from y199.3 to y148 points. This is a test-query defect. The test status remains failed. The image and frame evidence support the limited layout verdict above. Use a block predicate that reads the frame for any later test change. Do not repeat the accepted anchor journey for this query fix.

Evidence: `build/native-evidence/L08/reader-top-edge-02-run.txt`, `reader-top-edge-02.xcresult`, and the top/small-scroll images. Full Reader typography and paired source/native visuals remain open.
