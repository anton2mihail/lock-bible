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
