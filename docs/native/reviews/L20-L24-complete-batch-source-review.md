# Complete Works, media, and Settings source review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: target compilation passes. Product runtime and parity remain open.

`build/native-evidence/L06/works-content-build-03.log` ends with `TEST BUILD SUCCEEDED`. This target includes Works, media, complete Settings, and the moved Rosary catalog models. Earlier missing model types and the Debug optional URI error are corrected. Parse checks alone did not accept these changes.

Main owns target membership, Runtime, navigation, simulator operations, and L22 notices. Source owns the isolated Works, media, and Settings files. No notification implementation exists at this checkpoint. Use the frozen L22 queue and permission contract when Main starts that ticket.

## Required source corrections

| Trigger | Required behavior | File |
| --- | --- | --- |
| Decode an empty Rosary media catalog | Reject invalid data and show a load error. Do not force-unwrap the first episode. | `RosaryCatalogModels.swift`, `RosaryMediaView.swift` |
| Return to a retained media screen | Activate the model again. Exit must release its player and observations. | `RosaryMediaModel.swift`, `RosaryMediaView.swift` |
| Leave the active scene | Pause playback. Do not resume automatically. | Media model and view |
| Switch episode while a periodic callback is queued | Reject callbacks from the old player. | `RosaryMediaModel.swift` |
| Start or pause audio | Update observed playback state and the button label. | Media model and view |
| Use video transport | Provide native play, pause, and seek controls. Keep background playback and PiP disabled. | `RosaryMediaView.swift` |
| Build Release | Exclude sample URLs and the Debug rights card. Keep the official-site action. Remove the extra series footer. | Media model and view |
| Show media headings and selected modes | Use source 36/44 and 12/18 heading metrics. Selected text uses the source card color. | `RosaryMediaView.swift` |
| Use larger text in Settings | Wrap choices without clipping. Keep identifiers on individual controls. | `FullSettingsView.swift` |
| Show Settings | Restore the source calendar row icon, subtitle, and spacing. Remove the added root width cap. Use source title spacing and About colors. | `FullSettingsView.swift` |
| Change Works appearance | Rebuild attributed pages with the new color. Preserve the current anchor. | `WorkReaderView.swift` |
| Complete a queued Works save after exit | Preserve the durable save. Suppress feedback for the departed route. | `WorkReaderView.swift` |
| Insert a new status message | Announce it through a stable observer or an initial event. An observer added inside `if let` does not observe the earlier state change. | `ContentPage.swift` |

The earlier L23 handoff said Release rights copy. The actual source rights card is guarded by `__DEV__`. This review corrects that statement. Source text and official links remain unchanged.

## Export and announcement boundary

Scripture cards use a measured preview height and an unbounded proposed render height. `ImageRenderer` uses `1080 / previewWidth` as its scale. The PNG goes to a native activity sheet. Completion, dismissal, and exit remove its temporary file. This mechanism is suitable for runtime checks. Verify the actual PNG pixel width and height with a long passage. Confirm complete text, both presets, text fallback, and cleanup. No new prototype is required.

The shared status modifier calls `UIAccessibility.post`. Its initial observation needs the correction above. Runtime evidence must confirm an actual announcement after a successful or failed action.

## Next coherent simulator batch

Use a valid schema-1 library for note create, edit, delete, and undo. Confirm each Saved filter and preserved edition identity. Continue with the current content, Works, media, and Settings routes. Record installed/product hashes and actual process paths.

Keep the short Reader proof in this batch. The previous verse-8 union frame partly overlapped the viewport, while its owned word was outside the visible text area. Scroll from an owned glyph or word rectangle. Require its center inside the viewport with a margin. Do not tap a fraction of the union frame. Do not change product blank-space hit behavior. The required sequence remains `10,12,8,8,8`. Normal valid-library John, Psalm, Song, and Aa comparisons remain open.

Gate A stays accepted. Gates B, C, and D remain open. All 29 route comparisons remain required.

## Source correction commit

`8ddb2dc` contains 25 isolated content, Works, media, and Settings files. It excludes Main integration and Core. The lifecycle, native video controls, catalog validation, initial announcement, appearance reflow, and exit feedback changes are present. Source parse passes. The current correction commit still needs target compilation and simulator evidence.

The remaining narrow findings are a validity guard before media foreground activation, first-episode fallback on invalid route changes, intrinsic wrapping Settings choices instead of equal-width grid cells, and removal of added media count/scaling styles. Main still needs to replace the old Settings root after its notification callback is available. Notifications remain open.
