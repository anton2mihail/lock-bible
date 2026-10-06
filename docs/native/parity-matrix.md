# John 1:1 parity matrix

Updated: 6 October 2026. Baseline JavaScript source version: **1.5.0 (18)**. The old built app reports native bundle version **1.2.2 (15)**. These values differ.

This matrix records the current Expo app as the baseline. `Source-only` means the route or behavior comes from source inspection. It does not mean that the simulator showed it. The simulator checks are in progress. Keep each unvisited state marked `Pending`.

| Route | Entry / return | Initial state and required checks | Source evidence | Simulator evidence |
| --- | --- | --- | --- | --- |
| `/` Today | Today tab; return to selected tab | Date, season art, observance, readings, suggested Rosary, morning/evening prayer at 17:00, ongoing novenas, verse, Sunday preparation, faith/confession links | `src/app/(tabs)/index.tsx` | Observed: clean Today root, date, content cards, and all five tabs. Remaining Today states are source-only. `07-release-launch.png` |
| `/read` Reader | Read tab; retain current chapter and position | Book list, chapter grid, continue reading, chapter text, previous/next, Aa settings, verse actions, commentary links | `src/app/(tabs)/read.tsx` | Observed: book list, John chapter list, John 1 WEB-CE, Psalm 23 heading/poetry, active verse selection, saved gold highlight, note editor, Aa live Large restyle, Search close returning to John 1, and five tabs. `08-reader-john-1.png`, `09-aas-live-large.png`, `10-reader-john-1-highlighted.png`, `11-reader-search-return.png`, `12-reader-psalm-23.png` |
| `/saved` Saved | Saved tab; open item in Read; return to Saved | All/bookmark/highlight/note filters, sort order, snippets, context, deletion, undo, empty/error states | `src/app/(tabs)/saved.tsx` | Pending |
| `/pray` Prayer home | Pray tab; open detail and return | 27 novenas, needs search, Rosary/Seven Sorrows, prayer library, Lectio, Confession, learning links | `src/app/(tabs)/pray/index.tsx` | Pending |
| `/settings` Settings | Settings tab; return to selected tab | Reading, appearance, translation, verse pool/cadence, widget instructions, calendar, coverage, attribution | `src/app/(tabs)/settings.tsx` | Pending |
| `/go-to` Go to | Reader action/sheet; return to same chapter | Every book, expanded current book, marked current chapter, preserve reader context | `src/app/go-to.tsx` | Pending |
| `/search` Search | Reader search; close returns to same chapter | Reference parser, prefix/phrase FTS, correction, scopes, result marks, loading/errors, result opens in Read | `src/app/search.tsx` | Observed: Search Scripture form and live keyword results opened from the Read list. Reader return behavior remains pending. |
| `/note` Note editor | Selected verse action; return to passage | Load existing note, explicit save, empty note, errors, keyboard avoidance, passage identity | `src/app/note.tsx` | Observed: note editor opened for John 1:1 and saved text into SQLite. Empty/error/return states remain pending. |
| `/verse` Verse moment | Widget/deep link; dismiss returns to app | Deterministic verse, countdown, share text, read in context, dismissible widget guide | `src/app/verse.tsx` | Pending |
| `/daily?date=…` Daily readings | Today card/date link; return to Today | Exact local date, readings/observance, source link, missing-reference state | `src/app/daily.tsx` | Pending |
| `/sunday` Sunday preparation | Today link; return to Today | Upcoming Sunday including today, Gospel links, reflections saved by Sunday date | `src/app/sunday.tsx` | Pending |
| `/passage?reference=…` Passage context | Reading or saved item; return to caller | Citation parsing, WEB-CE context, chapter mapping, context explanation | `src/app/passage.tsx` | Pending |
| `/lectio` Lectio | Prayer home; back/continue/finish | Selected/current passage, five steps, navigation, silent one-minute timer | `src/app/lectio.tsx` | Pending |
| `/prayers` Prayer library | Prayer home; return to Prayer | Groups, exact prayer titles/text, favorites, existing ordering | `src/app/prayers.tsx` | Pending |
| `/prayer?id=…` Prayer detail | Prayer library; related prayer links; return | Exact wording/source, favorite state/action, related prayers | `src/app/prayer.tsx` | Pending |
| `/learn` Teaching library | Prayer home; return to Prayer | Five topics, exact copy, art, links | `src/app/learn.tsx` | Pending |
| `/teaching?id=…` Teaching detail | Teaching library; return | Summary, Scripture, CCC citation, Vatican URL, reflection prompt | `src/app/teaching.tsx` | Pending |
| `/confession` Confession | Prayer home; clear on leaving | Examination, guide steps, temporary note, explicit finish/clear, note cleared on exit/background | `src/app/confession.tsx` | Pending |
| `/share-card` Scripture card | Verse or selection action; system share return | Selected text/reference/edition, ivory/plum backgrounds, PNG export, text fallback, errors | `src/app/share-card.tsx` | Pending |
| `/calendar-notifications` Calendar notices | Settings; return to Settings | Opt-in, time, schedule capacity/errors, date tap destination | `src/app/calendar-notifications.tsx` | Pending |
| `/pray/[id]` Novena detail | Prayer home; return to home | Art, patronage, dates/source, intention, day selection/completion, continue/reset | `src/app/(tabs)/pray/[id].tsx` | Pending |
| `/pray/rosary` Rosary home | Prayer home; return | Suggested set, four mystery sets, art, Seven Sorrows, links, release media state | `src/app/(tabs)/pray/rosary.tsx` | Pending |
| `/pray/rosary-guide?set=…` Rosary guide | Rosary home; back/finish | Five decades or distinct Seven Sorrows, prayers/repetitions, bead rail, progress, announcements | `src/app/(tabs)/pray/rosary-guide.tsx` | Pending |
| `/pray/rosary-reminder` Rosary reminder | Rosary home; return | Daily/weekly schedule, time/weekday, permission, disable/update | `src/app/(tabs)/pray/rosary-reminder.tsx` | Pending |
| `/pray/rosary-media?episode=…` Rosary media | Rosary home; return | Six catalog entries, official links, audio/video states, approved direct stream only | `src/app/(tabs)/pray/rosary-media.tsx` | Pending |
| `/works` Works library | Direct route/tab link; open collection | Collections/counts, available filters/search, resume card, catalog-only startup | `src/app/works/index.tsx` | Pending |
| `/works/author/[id]` Collection | Works library; return | Collection order, work kind grouping, title/length, attribution | `src/app/works/author/[id].tsx` | Pending |
| `/works/[id]?section=…` Work reader | Collection/commentary; return | One section at a time, pagination, contents, page/section control, resume, loading/missing/errors | `src/app/works/[id].tsx` | Pending |
| `/commentary/[book]/[chapter]` Commentary | Reader link; open work section; return | Chapter/homily index, exact title/author, work/section destination | `src/app/commentary/[book]/[chapter].tsx` | Pending |

## Cross-route checks

| Check | Expected baseline | Evidence |
| --- | --- | --- |
| Five tabs | Today, Read, Saved, Pray, Settings in that order | Observed on Today and Read roots. The AX tree reports Today, Read, Saved, Pray, Settings in order. Other roots remain pending. |
| Reader return | Search and Go to keep the current reader; result/context opens select the requested passage | Observed: closing Search from John 1 returned to John 1. Go to and opening a search result remain pending. `11-reader-search-return.png` |
| Edition | Saved context keeps its saved edition; current setting controls later saves | Pending. No edition-change test was run. |
| Saved edition discrepancy | Saved rows must use their saved edition when they open Read or Note | Pending. Source review found that the Saved route does not pass its stored translation ID to Read or Note. The native migration must use the stored edition. Runtime reproduction is still open. See `docs/native/reviews/S00-source-discrepancies.md`. |
| Selection | Live selection differs from saved highlight fill | Observed: a tap selected John 1:1 and exposed the action sheet; applying gold saved a persistent gold fill. `10-reader-john-1-highlighted.png` |
| Local date | Gregorian local date keys; coverage fallback is clear | Pending |
| Offline | Reading and prayer remain available offline | Pending |
| Small / large layouts | iPhone and iPad; default and large text; light and dark | Pending |

## L00 route / build notes

- Simulator and runtime: iPhone 17 Pro (`iPhone18,1`), iOS 26.5 runtime `23F77`, UDID `37D1870B-F16D-488A-8F20-959201F970D9`; Xcode 26.6 build 17F113.
- Release simulator build result: passed. Log: `build/native-evidence/L00/old-app-release-build.log`. Native `CFBundleShortVersionString=1.2.2`, `CFBundleVersion=15`; JavaScript source `1.5.0 (18)`.
- Bundle IDs: `com.nrsv.verse` app, `com.nrsv.verse.widget` widget. Source App Group ID: `group.com.nrsv.verse`. URL schemes: `nrsv`, `com.nrsv.verse`, `exp+nrsv`. Build used `CODE_SIGNING_ALLOWED=NO`; app group entitlement and widget shared data were not verified.
- Actual app data container: simulator `.../Containers/Data/Application/7FA0CAAF-5F22-4446-854C-C902C7EBBE21`.
- Actual storage: `Documents/SQLite/bible-search.db`; `Documents/SQLite/user-library.db` (user_version 1, WAL journal mode, with live WAL/SHM files); `Documents/mmkv/mmkv.default` and `Documents/mmkv/mmkv.default.crc`; `Library/Preferences/com.nrsv.verse.plist` and `group.com.nrsv.verse.plist`.
- Synthetic fixture copy: `build/native-evidence/L00/synthetic-legacy-fixture/`. It contains one bookmark, one gold highlight, one note, reader preference state, SQLite files, MMKV data/CRC, and preference plists. The original container stayed in place. Sol must review the separate storage worker's mode before any storage proof uses a fixture copy.
- Clean Today and John 1 Reader screenshots use light appearance, 1206 × 2622 pixels (402 × 874 points), status time 9:41, and default Medium/Comfortable/Serif/Paragraphs reader settings. Aa capture uses Large text. See `docs/native/work-ledger.md` for capture details.
- Simulator-observed states: Today root; Read tab root; book and chapter selection; John 1 prose; Psalm 23 heading and poetry; Aa settings; live Large restyle; verse selection; gold highlight; note editor and saved note; Search Scripture entry/results; Search close returning to John 1.
- Source-only routes and unvisited states: all other matrix rows and states remain unverified. Do not infer runtime behavior from the source inventory at `docs/native/inventory/`.
- Screenshots and logs: `build/native-evidence/L00/`.

## Current native checkpoint

The baseline rows above describe the old app only. They do not describe the current native implementation. Gate A is accepted at Main integration `df8cc9b`. The current native app has the continuous chapter renderer, Search, Saved, devotional routes, Works, media, and complete Settings. Target builds prove inclusion. Full route and visual acceptance remains open.

| Native scope | Accepted evidence | Remaining route acceptance |
| --- | --- | --- |
| Foundation | Gate A storage, recovery, same-ID small Release import, native-wins restart, startup URLs, and shared state | Complete release fixture, signed widget continuity, and final update remain later gates |
| Reader / Go to / Aa | Production renderer builds; verse 10 and range 10–12 observed; valid-library Reader opens; UIKit capture reaches47:0, restart shows47, footer controls are above tabs in run10 | Full range sequence, owned continuation taps, final-layout/width anchor restoration, exact clipping boundary, matched John/Psalm/Song, all typography/edition controls, full visuals |
| Search | Repository/parser comparisons and three Build19 UI methods pass: reference/phrase/correction/no-results, scopes/editions/Latin, final quick-input state, close/return, repeat result | Full visuals, loading/error states, stale intermediate response behavior |
| Saved / notes / actions | All four filters, existing note edit/reopen/delete, bookmark delete/Undo pass at `8f66582`. Vulgate new note retains exact edition/text through WEB change and restart at `1d8fed9`. Bookmark save/four highlight control transitions/final clear pass at `f8a90bd` | Bookmark removal from toolbar, mixed-range/fill, errors, copy/share/Pray/Card, timeout/failure behavior, full visuals |
| Verse Moment / widgets | Rotation/repository comparisons pass. Exact2Timothy2:23 → Reader2Timothy2 → selectedverse23 withWEB-CE attribution passes. Three widget kinds and complete target source exist | Remaining Verse Moment controls/visuals, supported families, actual timelines/reloads/links, installed update retention |
| Daily / Sunday / passage / Today | Core fixtures and target compilation pass. Sep13 reflection restart passes; dated Daily/Sunday and Sirach context entry assertions execute before the L15 helper failure | Other mappings/fallbacks, 17:00 behavior, full route states and old/native comparisons |
| Prayer / Novena / Teaching | Complete source and exact fixtures exist. Morning favorite and Padre Pio intention/day1 completion/day2 selection survive a restart on Build19; Eucharist entry/return assertions execute | Other search/reset/persistence states, source text/links, complete return paths, visual pairs |
| Rosary / Seven Sorrows / Lectio / Confession | Complete source exists. Build19 Confession notes remain during steps and clear on background/exit/Finish; no persistent note field/row remains | Distinct guide sequences, completion/back/reset, quiet timer, announcements, visuals |
| Scripture card | Short ivory PNG is1080×1440; nativeCopy action dismisses the system panel and removes the new temp file | Both backgrounds, long text, preview agreement, repeat/cancel cleanup, text fallback, iPad, full visuals |
| Works / Collection / Commentary | Repository compatibility and target compilation pass | Catalog navigation, exact destination, pagination, anchor/reflow/restart, contents, lower controls, long/missing states, visuals |
| Notification settings / schedules | Corrected service6e87cfa and helper3e909b1 are accepted; simulator process13149 passes all25 injected-center observations | Actual OS permission/pending round trips, lifecycle refresh, real delivery, cold/warm tap, route visuals |
| Media / complete Settings | Source review and coherent target compilation pass | Player lifecycle/failure, Release gate, every preference/credit/coverage control, source-matched images |

No complete native route parity is claimed. The ordered remaining checks are in `reviews/Remaining-gate-runtime-order.md`. Preserve old-app and native images as separate evidence until their states match.
