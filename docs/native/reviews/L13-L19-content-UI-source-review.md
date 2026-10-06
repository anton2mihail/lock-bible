# Content UI source review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: implementation continues; source corrections required.

Source owns the new feature files. Main owns integration and simulator control. The route enum matches the accepted callback contract. The prayer favorite queue derives changes from the latest committed snapshot and awaits the durable save result. Keep this behavior.

The first shared components differ from `src/components/companion/Companion.tsx` and `src/components/Text.tsx`. Apply the source metrics before visual acceptance.

| Trigger | Required behavior | Native file |
| --- | --- | --- |
| Open a content page | The 740-point width includes 24-point side padding. Bottom content padding totals 48. Back uses 14/21. Subtitle uses 16/24. Lora title uses 36/46. Eyebrow uses 11/18. | `ContentPage.swift` |
| Show a section title | Use 20/32 medium text. Support optional detail at 14/21. | `ContentPage.swift` |
| Show an action row | Keep 12-point vertical padding inside the 72-point minimum. Use 14/21 subtitle, optional 64-by-76 thumbnail, and pressed opacity 0.65. | `ContentPage.swift` |
| Show a panel | Arrange children with a 16-point gap. Keep 20-point padding and 18-point radius. Use a border of one physical pixel. | `ContentPage.swift` |
| Prayer catalog load fails | Show the load error. Do not enter the empty-search result branch. | `PrayerLibraryView.swift` |
| Enter only spaces in prayer search | Return all matching prayers. Hide Kept close because the raw query is nonempty. | `PrayerLibraryView.swift` |
| Show category rows | Do not add an eight-point gap between each source action row. | `PrayerLibraryView.swift` |
| Open a prayer | Use Lora 24/36 body text and the source outlined default Button. Feedback uses 16/24. Keep exact text and artwork. | `PrayerDetailView.swift` |
| Reuse a prayer detail with a new ID | Load the new ID and reject stale results. Preserve the invalid-ID fallback. | `PrayerDetailView.swift` |

Source can continue other assigned content views while it applies these corrections. Main must capture matched old/native page, search, favorite, and error states before L16 acceptance. No content UI parity is accepted by this source review.

## Corrected source boundary

The shared file now puts the 740-point cap outside its padding. Its bottom content padding is 48. Action row padding is inside the 72-point minimum. Panel and row borders use the display scale. Section detail has the source eight-point gap. Native font metrics provide a line-spacing estimate; simulator baseline measurement remains required.

The prayer library now checks load errors before empty results. It uses the raw query for Kept close visibility and removes extra category row gaps. The favorite queue keeps the durable save boundary. Main can add the four new files to the next app build. Their complete UI and visual acceptance remain open.

## Daily, Sunday, and Today boundary

Source has added `CalendarReadingsView.swift` and `CompanionTodayView.swift`. The Daily/Sunday source now uses the upcoming Sunday as the invalid-date fallback. It keys the scroll page by date, uses the source 17/28 connection text, and captures the reflection date and draft before saving. Save feedback applies only to that captured date and draft. Runtime acceptance remains open.

Today requires the source root-page behavior without Back. Its Lectio action must carry the displayed verse and edition. A nil passage opens the fallback guide and loses the source route identity. Use the existing runtime passage resolver. Display the metadata abbreviation: WEB-CE, DRB, or VUL.

Main owns the shared metadata and rotation integration. The view's explicit date and time zone must also drive rotation. Refresh on changed rotation preferences and committed novena progress. Keep one shared calendar cache when Main replaces the old Today root. Do not keep the old TodayModel calendar decoder alongside the companion repository.

Shared view types used across feature files need internal access. A frontend parse does not check cross-file private access. Main must compile the complete file set before source acceptance of these views. Lora baseline distances and large-text date-row wrapping remain focused runtime checks.

## Teaching, Confession, and Novena checkpoint

The dedicated Prayer root now uses the source SpaceGrotesk heading and root padding. Teaching, Confession, and Novena detail files are present. Source can continue Lectio and Rosary while it applies these corrections. No simulator acceptance is claimed.

- Teaching and Confession body text uses source 17/28 and the app text color.
- Teaching and Novena hero art uses aspect ratio 1.7, radius 18, and cover cropping. Novena library portraits crop to cover the 76-by-92 frame.
- Confession shows “Private notes, if helpful”. Disable correction and spelling. Keep notes across internal steps. Clear them on route exit, inactive scene, finish, and external resource action.
- A successful Novena reset clears the displayed intention. A failed intention save keeps the draft. A new route ID clears the old draft before loading and rejects stale loads and queue feedback.

Use local styles from `src/screens/NovenaScreen.tsx`. Generic companion panels do not match Novena cards. Dates belong inside the heading. The about card uses radius 16, padding 16, gap 12, and a three-point tint border on the left. The progress card uses radius 20 and vertical padding 16. Day numbers use 14/21 semibold text. The selected circle uses neutral800. A completed circle uses tint. The connector is 10 by 1 and follows the completion state of the next circle.

The intention card uses radius 16 and padding 16. Its input uses radius 10. The prayer card uses horizontal padding 24, vertical padding 32, radius 20, and gap 24. Opening text uses SpaceGrotesk 20/32 semibold. Prayer paragraphs use 18/30. Responses use 16/25 semibold, tint, and a two-point left border with padding 16. The source link is centered and underlined.

Use the actual source size aliases: sm is 16/24, md is 18/26, xs is 14/21, and xxs is 12/18. Local overrides still apply. Novena subtitle is 16/24. About text is 16/23. The earlier message with 17-point paragraphs and 14-point responses was corrected before implementation acceptance.

The coherent simulator batch must check notes across Confession steps, inactive clearing, intention reset, and failed-save draft retention. Capture Novena selected/completed states at default and large text. Parse checks do not prove lifecycle or visual behavior.

## Lectio and Rosary checkpoint

Lectio now has a whole-file source implementation. Its footer must use the passage edition's attribution. A book name is not the attribution. Missing or failed passage resolution must offer “Open the Bible” through an `onOpenBible` callback to the existing Read root. Keep the actual-passage callback separate. Do not make a placeholder passage. Use source 17/28 prompt text, 11/18 normal uppercase step labels with tracking 2, and 16-point action and passage gaps. Reset scroll on each step. Preserve deadline-based timer behavior.

The Rosary session transitions use the staged source session values. The first UI file shows artwork on prayer steps. The source shows artwork only when the step has no prayer and has a mystery index. Correct this condition. Use the guide's local source card, rail, header, completion, and action styles. Generic companion panels have different metrics. The source actions are vertical. Beads are 34 points. Bead numbers and the close glyph cap at 1.4 system scale. Prayer text uses 20/34; meditation uses 18/30. Completion centers within the viewport and uses a 36-point glyph inside its 96-point circle.

Main must compile these new files together before the content runtime batch. Check all five Rosary sessions against the accepted exact steps. Observe repeat, back, completion, and reset. Check artwork and credits on a mystery step and their absence on prayer steps. Media opening remains outside this guide check.

## Complete route-file boundary

Citation context and Scripture card files are present. The new route-file set can enter the coherent app compile after these concrete corrections. Source can start isolated Works files from `L20-L21-Works-handoff.md` in parallel. Shared Core writes still require a build boundary with Main.

Citation context must clear old target and chapter state before each reference load. An invalid reused reference must not show the prior chapter. Chapter changes and verse resolution need a load-generation guard. Preserve the source chapter title, reference subtitle, endpoint-disabled navigation, and Reader typography. Its “Search the Bible” callback opens Search. A Read-root callback is different.

Scripture card must export the rendered card as a 1080-pixel PNG and open the native share sheet. A text-only ShareLink does not complete L19. Keep a separate text fallback, busy and ready states, error feedback, and temporary-image cleanup. Preserve the source left alignment, spacing, wordmark, reference, and actual edition attribution. Use UTF-16 length for the 900-unit quote threshold. Remove the duplicate private `Color.init(hex:)`; the shared theme already supplies it.

Rosary home must use exactly the development-or-approved media gate. In development, its action opens the native media route. In release without approved media, it opens the official URL. Main owns the later L23 player. The official series footer remains an actual link. Reminder navigation has no permission or schedule side effect in this batch; L22 remains separate.

Full target compilation, rendered-image inspection, native share-sheet cancellation, citation navigation, and both media gate branches remain simulator acceptance items. No content placeholder or text-only export is accepted as complete.

## Final isolated source checks

The access identifier audit found a panel identifier on Today with two child buttons. Source moved `today-verse-card` to the verse Text. Prayer search and favorite identifiers are on their actual controls. Keep new identifiers on leaf controls or static text. The Saved runtime shows that a container identifier can replace child identifiers.

Scripture card now supplies a PNG and native activity sheet. Its current preview and export force a 480-point height. The source has a minimum height, and the plan requires full measured height at 1080-pixel width. Keep a 480-point minimum. Measure the complete composition at its real width and use that height for preview and export. A long passage must not lose text. Native image width alone does not complete L19.

The installed SwiftUI SDK has no public `accessibilityLiveRegion` modifier. Source must replace those uses with real supported announcements. Do not add a no-op modifier. Full target compilation remains required. Source can continue isolated Works files while Main integrates the content batch.

The frozen source now uses `UIAccessibility.post(notification: .announcement, argument:)` for message changes. Today has the corrected leaf identifier. Scripture card has variable height, native sharing, and temporary-file cleanup. Its `frame(width:minHeight:)` call still mixes two SwiftUI frame overloads. Split those modifiers. Capture the actual preview width and export the same composition at scale `1080 / previewWidth`; a fixed logical width of 360 can change line breaks relative to the preview.

Citation context still uses Lora and a separate verse-label column. The source has Georgia serif or the shared sans font, with an inline label. Apply the exact Reader typography and source unavailable title/copy. Recheck request generation after each suspended load, including attribution and failed-load branches. These are focused source fixes. The complete content batch can compile while the fixes enter at stable file boundaries. Full content runtime remains open.

## Coherent target compile

`L06/content-widget-build-05.log` reports TEST BUILD SUCCEEDED for the app and widget batch. The duplicate `verseMoment` route and mutable PreferenceKey default were corrected. Scripture card now uses a constant default, the measured preview width, scale `1080 / previewWidth`, variable height, and native PNG sharing. The mixed frame call is split. The announcement helper uses the supported UIKit API. This accepts target compilation only.

Citation now has inline text and the unavailable copy. Its actual serif font still calls the Lora helper, while its spacing measures Georgia. Its label is 12 points instead of source xs 14. Correct those values and put valid-chapter warnings inside the valid branch. Full source-matched rendering and runtime remain open. Works was not included in this compile evidence.

## Today rotation integration correction

The `anchor-works-share-01` tests stop at the Today action lookup. The source cause is a refresh guard: `CompanionTodayView` skipped rotation refresh when `fixedTimeZone` was present, while `JohnApp` always supplies the feature zone. This left the rotating verse and its actions absent.

Main removed that guard. The current source always refreshes rotation with the same captured date and time zone used by dated content. `TodayModel` computes the slot from those inputs. Runtime uses the current auto-updating zone unless DEBUG arguments provide a fixed date and zone. Release keeps real time. This accepts the clock input boundary only. The next coherent build and fixed-date/zone content check must prove the actual UI result. Read-to-Works provides an independent test entry.
