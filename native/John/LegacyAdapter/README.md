# Legacy MMKV adapter

This folder contains the app-only reader for the legacy MMKV store. It reads the `mmkv.default` data file and its `mmkv.default.crc` file. It does not write either file.

The app target must compile `LegacyMMKVAdapter.mm` and `LegacyMMKVReader.swift`. It must also compile the iOS source files in `Vendor/MMKVCore/Core.xcodeproj`, target `MMKVCore`. The source file list in that target is the build authority. Do not add `MMKVWatchCore` or the Swift bridge to JohnCore or the widget.

Use these build settings for the app-only adapter target:

- Define `FORCE_POSIX=1`.
- Set `CLANG_CXX_LANGUAGE_STANDARD` to `gnu++20`, as in the pinned `MMKVCore` target.
- Add `Vendor/MMKVCore` to the header search paths.
- Link Foundation, libc++, and zlib.
- Expose `LegacyMMKVAdapter.h` to `LegacyMMKVReader.swift` with the target bridging header.
- Link the target only to the app target.

`LegacyMMKVReader` requires CryptoKit and JohnCore. It checks that both MMKV files exist, hashes both source files, and then calls the read-only C++ adapter. The C++ adapter opens MMKV in `MMKV_SINGLE_PROCESS | MMKV_READ_ONLY` mode. It passes `false` for string in-place modification.

The vendored source is Tencent MMKV Core v2.0.0 from the locked `react-native-mmkv` v3.3.3 package. `Vendor/MMKVCore/LICENSE.TXT` contains the Core license and third-party notices. `Vendor/MMKVCore/vendor-sha256.txt` records the SHA-256 hash of each copied Core file. The source is unchanged from `node_modules/react-native-mmkv/MMKV/Core` at the time of the inventory.

The accepted integration uses `LegacyMMKVReader(rootURL:)` with an injected store root. The baseline source path is `Documents/mmkv`. `LegacyMMKVReader(appGroupIdentifier:)` is an alternate supported path. The source default MMKV ID is `mmkv.default`. The legacy app reads the `AppGroup` value from its generated Info.plist when no custom path is set. The source declares `group.com.nrsv.verse`. The effective container access and the actual container contents remain unverified until app integration checks them.
