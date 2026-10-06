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
