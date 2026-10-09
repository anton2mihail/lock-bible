# Oct 7 Reader scroll-reset checks

These three checks ran on the native Debug app at system Large. They verify current Reader behavior after the scroll-reset change. They are not XXXL acceptance evidence. Each check used a fresh native-only seed. The app debug library SHA-256 was `715acf45d3b3837b7257db80a92bffc9e1e83c03352eb53118e800979dc07810`. The test bundle SHA-256 was `00676473e84a0e832862d459fc27b1f65294eb11407f1cdcfbbd1f23fd1fc235`.

| Check | Result | Seed SHA-256 | Result bundle |
| --- | --- | --- | --- |
| Cold context URL | 1 passed, 0 failed. John 3:16 stayed visible. Request `EDFB0E3C-0096-4431-B060-6C405F7493D5` stayed current after 2.2 seconds. | `d5d6a27ae8222aeb4a01b2f56ea47b20e36fd9e82929be04d0f880521f27b881` | `build/native-evidence/L25/reader-regressions/oct7-cold-context/result.xcresult` |
| Saved non-top context | 1 passed, 0 failed. The test created a John 3:16 bookmark, opened it at verse 16, kept request `DB64F7D3-719A-4150-A3FD-004D716F29BE` current after 2.2 seconds, and showed no active selection. | `a0aea315d7a6270b43af042c58625c1e56a75ffa1bfedcda750f6b6c7bc84dc5` | `build/native-evidence/L25/reader-regressions/oct7-saved-nontop-context/result.xcresult` |
| Saved position return | 1 passed, 0 failed. The test saved John 1 anchor `10:39`, switched Today→Read, and restored John 1, verse 10, the same anchor, and request state after 2.2 seconds. | `ad76d55bef4eacddc553a5161ae3bdc08acfd5ccf61adb1476f7f2feefa609b8` | `build/native-evidence/L25/reader-regressions/oct7-saved-position-return/result.xcresult` |

All three test logs are beside their result bundles. The matching `.xctestrun` hashes are `31631dec287a891bc6a76a1ff45f1c90ff1152f33f2ae8fd7c5ff36a6c4f1d62`, `4ed8285935cfef16a1243f96fa871e1825fd71d1c9c043085883a560a00f4740`, and `53d45cc1eeb5ce4bb00b33d594125146b809df8071d3dfffbc7471b813dcb2e2` in the same order.
