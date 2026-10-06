# Widget source review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: source implementation present; focused corrections and runtime remain open.

`JohnWidget.swift` now has separate Verse, Countdown, and Daily Reading providers. It uses the accepted indexed reader and Core rotation math. Widget kinds, family lists, metadata, daily files, eight daily entries, dated Daily URL, and displayed-verse URL match the source boundary. This review does not prove effective App Group access or WidgetKit rendering.

Correct the Countdown timeline against `targets/widget/VerseWidget.swift`. The current first entry uses `now` as its start. The source uses the start of the current rotation slot. Circular progress must include elapsed time. All planned starts and ends use the offset at the reference `now`; do not change future end offsets in this port. The accepted Core math remains unchanged.

Restore the source home-screen countdown styles: 13-point medium rounded title, 34-point bold rounded timer, and lowercase “up next” with 12-point semibold rounded secondary text. Center the circular timer label. The source timer has no widget URL. Remove the added hardcoded John 1 destination. Verse taps already use their displayed passage.

Main applies these fixes in the coherent widget build. Observe an in-slot circular countdown, a DST-spanning planned timeline, the three widget types and required families, exact displayed-verse and dated Daily taps, daily coverage fallback, and durable shared preference projection. Keep unsigned App Group limits explicit. Do not repeat the accepted 792-row Core comparison unless the math or corpus changes.

The corrected Countdown source uses the full current-slot start and the reference-now offset for all ends. Home-screen fonts and copy are corrected. The hardcoded timer URL is removed. `L06/content-widget-build-05.log` reports TEST BUILD SUCCEEDED. Widget rendering, timeline observations, taps, and effective shared access remain open.

The app's `VerseMomentDestination` remains partial. Complete the source countdown and 30-second focused refresh, text sharing, widget instructions, expanded steps, durable guide dismissal, and adaptive layout from `src/screens/VerseOfDayScreen.tsx`. Carry the displayed verse's edition in the route and passage resolution. A later changed preference must not resolve a different edition behind the displayed text. The current partial page does not complete L12.
