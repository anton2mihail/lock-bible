# L04 legacy MMKV root review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: source and archive metadata checked. Signed runtime access remains open.

The pinned React Native MMKV wrapper uses the `AppGroup` Info.plist key to select a group path. An App Group entitlement alone does not select that path. `AppGroupIdentifier` is not the key read by this wrapper.

`src/utils/storage/index.ts` creates `new MMKV()` without a custom path. `node_modules/react-native-mmkv/src/createMMKV.ts` asks for a group directory on iOS when no path is set. `ios/MmkvPlatformContextModule.mm` reads `AppGroup`. If the key is absent, it returns no group path. Its base directory is `Documents/mmkv`. If group access throws, the JavaScript wrapper logs the error and continues with the base path.

| Archive | Version and build | App Info.plist group keys |
| --- | --- | --- |
| `build-1782493545296.ipa` | 1.0.0 (3) | None |
| `build-1789946178491.ipa` | 1.3.0 (16) | None |
| `build-1790194947387.ipa` | 1.5.0 (18) | None |

All three archived apps use `com.nrsv.verse`. Source also inspected their signed executable entitlements. Each declares `group.com.nrsv.verse`. The current generated `ios/LockBible/Info.plist` has no group key. These checks support the observed `Documents/mmkv` baseline. They do not prove access to a signed shared container, or the root used by a different wrapper version in an older archive.

The archive hashes and limited metadata are in `build/native-evidence/L04/legacy-root-provenance/README.md`. Its SHA-256 is `4e57ce08feff6017ef1ada25d2d2d3c689c453edba5bf1ea540d15b62a8ca6e1`. The current ad-hoc signed dev simulator product has no application-group entitlement. Its configured entitlement file does not prove runtime group access.

Before final migration acceptance, inspect the actual signed app entitlements. Run an ad-hoc signed simulator group-access check where supported. Record `containerURL(forSecurityApplicationGroupIdentifier:)`, file presence, and read-only adapter results without private values. Verify the Documents path and an injected group path separately. Keep all source data and CRC bytes unchanged. Record any simulator limit. Use a physical device only when the simulator cannot prove the required signed-update behavior.

The native app currently injects the observed Documents root. The adapter also supports an injected group root. Do not silently choose defaults if a supported legacy install has valid group data. If more than one candidate contains different data, preserve both and report the conflict before import. Widget shared preferences are a separate store; do not treat those scalar values as legacy MMKV.
