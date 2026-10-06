# L19 long Scripture Card runtime review

Date: 6 October 2026.
Reviewer: GPT-6.1 Sol.
Verdict: accepted for the recorded iPhone 17 Pro profile. Full route parity and Gate C remain open.

## Recorded result

`build/native-evidence/L20/card-works-batch-01/card.log` records one passing method in 165.491 seconds. The test uses actual Reader controls to select WEB-CE Psalms 2:1–12. It checks the exact singleton and range references before it opens Card. Default text size, Comfortable spacing, Serif, and Verse by verse are committed before chapter entry.

The two word points have separate loaded-image and successful-tap evidence. The Card helper uses their offsets from the live verse frames. In this run, verse 12's point is `(120,175.7)`, rather than the diagnostic's absolute `(120,324)`. This confirms the need for frame-relative conversion. No product hit behavior changed.

The method checks preview text, reference, and edition. It exports ivory, cancels the native share panel, exports plum, cancels again, and repeats plum export. Main starts each read-only watcher before export. Each watcher logs `READY` with `baselineCount=0`.

| Capture | Dimensions | SHA-256 |
| --- | --- | --- |
| Ivory | 1080×4171 | `5a07476f4be7bab28a65d6162aba4db6e12d1bbfee667d67e3603be238771a83` |
| Plum | 1080×4171 | `854d0c9e91320d372547db1a6ba8cccc6c7830447c8d439be637946b37248209` |
| Plum repeat | 1080×4171 | `854d0c9e91320d372547db1a6ba8cccc6c7830447c8d439be637946b37248209` |

The watcher records a distinct new source filename for each capture. Its copied hash equals the source hash. Sol inspected the preserved ivory and plum pixels. Both contain all 12 verses through the final sentence, `Psalms 2:1–12`, and `WEB-CE`. Their backgrounds are visibly different. The `JOHN 1:1` wordmark matches the source `ShareCardScreen`; it is the fixed app wordmark. The plum repeat is byte-identical to the first plum export.

The zero-file watcher baseline before each later export proves that the earlier PNG was absent then. Main reports zero Card PNGs in the task app's temporary directory after the final cancel. This accepts cleanup for these three exports. The earlier short ivory native Copy check remains separate.

## Provenance and limits

- Test source: commit `08ce17c`, SHA `7756eb1a91754d2228812c84bde6db614a01069809dc0965792be8df85dd8c56`.
- Watcher: SHA `2f7a11d2894c4b6df186fa69592f25919e31d0438d50e4c10364e3f039edbce8`.
- Main reports matching product and installed executable SHA `08276bba7ba376f67d1b62cb96221e3bf5a77db0e482df2ed1e7f988e1aaf662` and dylib SHA `77bf55787397689ed7d4eb989c9aac2e350b0095d2f70a37ed4a9a7240e40ce9`. Sol independently hashed the current matching products.
- Builder PID: 93468. Test runner PID: 93533. The actual app PID is not yet available in the frozen report. PID69399 belongs to an older Release run and is excluded.
- Captures and watcher records: `card-works-batch-01/captures/{ivory,plum,plum-repeat}/`.
- Copied post-run envelope: `card-works-batch-01/post-run-snapshot/native-state-v1.json`, revision 23, WEB-CE, Medium/Comfortable/Serif/verses.

This accepts complete long-text PNG output, both backgrounds, preview text identity, repeat export after cancel, native panel cancellation, and temporary-file cleanup in this profile. It does not accept exact old/native visual pairs, text-sharing fallback, image/artwork failures, other font/device profiles, or iPad presentation. The iPad test is explicitly skipped until its owned word points have separate evidence. No PNG rerun is required solely to obtain an app PID.
