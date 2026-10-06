# Simulator App Group entitlement boundary

Date: 6 October 2026.
Reviewer: GPT-6.1 Sol.
Verdict: configured and embedded simulator group matches. Effective access and device signing remain open.

The immutable package is `build/native-evidence/L28/mapped-debug-build-01/John.app`. Its app executable hash is `4ab83515352af7e5b84eb362b20a154047a3017aa215bdc63401e8507206d247`. The embedded widget executable hash is `553cc86c9b0fb20f87b72cc45673cf302cbaa7673928471dd21c647e5cb60e65`.

`codesign -d --entitlements :-` returns an empty entitlement dictionary for both binaries. The resource verifier correctly records that signed dictionary. It does not inspect the simulator's embedded entitlement section.

Both frozen Mach-O binaries contain `__TEXT,__entitlements`. Direct read-only extraction of the XML gives:

| Binary | Embedded application identifier | Embedded App Group |
| --- | --- | --- |
| App | `QZ44N522NQ.com.nrsv.verse.dev` | `group.com.nrsv.verse.dev` |
| Widget | `QZ44N522NQ.com.nrsv.verse.dev.widget` | `group.com.nrsv.verse.dev` |

The app XML is at file offset 13550, size `0x180`. The widget XML is at file offset 13634, size `0x187`. These offsets apply only to the recorded binaries.

The project generator selects `Config/John-App-Development.entitlements` and `Config/John-Widget-Development.entitlements` for Debug. Both files declare the same development group. Release selects the separate update files with `group.com.nrsv.verse`. Current build intermediates also contain matching `*-Simulated.xcent` records. Ordinary `.xcent` dictionaries are empty. The frozen embedded XML is the package evidence; the current intermediates are supporting build evidence.

No source group correction is indicated by the empty signed dictionary. Do not infer a signing blocker or effective container access from it. During the widget check, Main must record actual app and extension container access, shared preference revision, and matching rendered state. Keep simulator-embedded entitlements separate from the final device/archive signed entitlement check.
