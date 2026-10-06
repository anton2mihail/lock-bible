# Rosary, Lectio, Settings, and Works runtime review

Date: 6 October 2026. Reviewer: GPT-6.1 Sol.

The Build21 feature batch has one passed method and three failed methods. Its results do not provide full gate acceptance. The separate Lectio method passes. Both runs use the same verified app product on iPhone 17 Pro, iOS 26.5.

## Product and input evidence

Product and installed executable SHA-256: `8bd5c3abe2ad14820d53b6e0108e5f96a8f6a47217553d94d76e292ceae2e895`.

Product and installed debug library SHA-256: `43e7ee93f576836216a0f6526345657b886e0dc246ff4f34e86dbc063aa17ce2`.

The fresh state seed hash is `8adb3abc3fa418af0862015727aed7c90f28aa74735aaaa3b678f4faebe48d39`. Feature batch runner PID is 65820. Failure trees identify L15 app PID 65857 and Works app PID 68919. The records do not supply a separate L17 or Lectio app PID. No repeat is required solely to obtain those missing process fields.

Evidence: `build/native-evidence/L08/feature-batch-02/run.txt`, `feature-batch-02.xcresult`, and `feature-batch-02-attachments/`.

## Accepted bounds

The Joyful guide completion/reset method passes in 237.020 seconds. It checks initial progress, forward and back movement, completion controls, and Pray again returning progress to 0 percent. Its loop is bounded by the source's 80 actions. It does not establish an exact runtime action count. Return to Rosary is visible but is not tapped. This accepts the tested Joyful completion/back/reset behavior. Other guide sequences, announcements, and full visual parity remain open.

The L15 method reaches Joyful, Sorrowful, Glorious, Luminous, and Seven Sorrows. It then closes the guide and taps the already-selected Pray tab. The failure tree shows Rosary home. The expected Prayer home action is absent on that route. This is a test route error. No timer check runs in this method. Do not repeat the successful guide entry checks solely to reach Lectio.

The separate Lectio method passes in 23.549 seconds. It enters from Prayer home, checks the guide steps, observes a numerical countdown from 60 to 59, uses End, and observes stillness. Runner PID is 70667. The state seed and post-run state hashes match. Evidence is `build/native-evidence/L08/lectio-timer-01/run.txt` and `lectio-timer-01.xcresult`. Natural timer expiry remains open. Collect it with a later Lectio route capture.

## Remaining Settings and Works checks

The Settings method completes its preference changes and restoration. It checks the three edition metadata/attribution blocks and coverage/credits before opening Aa. The final image shows Default, Paragraphs, System, WEB, Comfortable, and Serif. Aa line spacing returns an empty accessibility value. This is a missing accessibility projection; it does not show a failed durable save. Main adds explicit committed display values to the five remaining Aa selectors. Check those six values in a short Aa-only method. Do not repeat the completed Settings prefix for this correction.

The Works method opens Homily 10 and the section-10 footer. The copied state records section index 9, page 0, and paragraph-0/offset-0 anchor. The test queries `works-prose-text`, but the actual TextView identifier is `works-prose`. Source corrects both queries at commit `9193a91`.

The Works image also shows a product defect. Text forms one wide horizontal line with a largely empty viewport. The accessibility tree reports a 402-point TextView but text bounds about 4,732 points wide. Selector correction alone cannot accept this layout. Source commit `b3d607d` constrains UITextView to the finite proposed width. Source hash is `79a2265290b09f1329b8a2162f12a3261d17f4562ff814e7b3a5c2a714494203`. Its simulator SDK build passes. Actual wrapped-page, reflow, and restart checks remain open.

The reviewer viewed `frames/settings-final.png` and `frames/works-final.png`. Their hashes are `92b98a12c075687c4bf52336757bd7d82968fb2d128524a6716a9e0d9a68de36` and `8da35c2bf4c1524d2983ac21c856c513c4e28c416fadfbbaf445ba23254fac52`. The frame manifest hash is `b66075e2b7c45d5c6f95e075e1adab92ed22489699e22ab3776e78b77abc75e1`.

Final feature-batch state hash: `e094019866f2796a2c0434497caf890b28fc5780523e3d9c06d3cb8b0a7e2011`. Revision 22 contains the restored default preferences and initial Homily 10 position. It does not prove Works restart or readable page layout.

Gates B through E remain open. Keep accepted bounds separate from source preparation and final visual acceptance.
