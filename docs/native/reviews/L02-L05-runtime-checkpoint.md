# L02 and L05 runtime checkpoint

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: foundation source and runtime accepted at `c997283`. Gate A remains open.

Sol inspected the clean L02 Today, John 1, Aa, Large reader, and Settings images. The images use the pinned iPhone 17 Pro and iOS 26.5 simulator. The development app and widget build report states that Swift 6 strict checks passed. The runtime report records all five tab roots and their accessibility identifiers.

The images prove local fonts and artwork, a flat five-tab bar, a real WEB-CE verse, live text size changes, and the same Large value in Settings. The source Reader baseline uses its own header and continuous chapter text. The new one-verse card is shell evidence. It does not prove Reader parity. The native Aa sheet and Settings are also initial controls. Their full source layout and behavior remain L08 and L24.

The preferences remain in memory. The startup import, durable writes, cold and warm URL queue, repeated equal URLs, and recoverable invalid destinations remain open. Unsigned products do not prove effective App Group access. Full widget providers and timelines remain L12.

Main made the scoped foundation commit `c997283`. Post-cleanup file integrity still needs an explicit record. Source must complete the storage fixes in `L04-storage-code-review.md`. Main must then run the integration matrix in `L04-runtime-acceptance-contract.md`. Gate A needs these results before acceptance.

Main may prepare bounded L06 and L07 Reader work after its foundation commit. It must use accepted Core and renderer contracts. Storage readiness still controls integration. This staged work does not change the Gate A status or remove any later route checks.

Sol inspected the expanded UI test and its second-run log. One test passed with zero failures. It checks each primary root, internal John 1:1 opening, Large selection, Aa closure, and the shared Large value in Settings. The first run found a missing sheet close action. Main added Done before the passing run. External URL startup and repeated delivery still need their own checks. Log: `build/native-evidence/L02/xcodebuild-ui-test-strong-02.log`. Result bundle: `build/native-evidence/L02/John-Development-UI-02.xcresult`.

Evidence: `docs/native/L02-runtime.md`, `build/native-evidence/L02/`, and `build/native-evidence/L00/08-reader-john-1.png`.

## CI source review

The corrected workflow stages the paths read by the project. It pins Xcode and finds the required simulator through `simctl` JSON. It does not use the local device ID. These source changes pass review. A hosted CI run remains unobserved.

The runner label and installed toolchain were checked against [GitHub runner documentation](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) and the [macOS arm64 image list](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md). Check date: 5 October 2026. Image contents can change. The workflow must retain its explicit toolchain and runtime checks.
