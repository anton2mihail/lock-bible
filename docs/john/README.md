# John 1:1 Catholic companion

The app retains its John 1:1 display name and existing installation identifiers.
The current icon depicts an ivory Chi Rho Christogram with restrained gold edging on plum. Artwork prompts in
this directory preserve their original wording, including the earlier proposed
Vesper name.

Implemented: a liturgical Today page, daily reading references, Sunday preparation
with locally saved reflections, a five-step Lectio Divina guide, everyday prayers
and favorites, Scripture and Catechism topics, a guided confession examination,
and illustrated Scripture sharing cards. Rosary mysteries and novena saints have
new devotional artwork.

The calendar uses the United States Roman Rite (Sunday Ascension); local
observances can differ. Bundled reading references cover all of 2026 and 2027;
other dates link to the official USCCB page when local references are unavailable.
Reading links open the relevant WEB-CE chapter in context; exact lectionary
wording and optional readings remain on USCCB. Sunday prompts are editorial,
with selected Gospel connections rather than a unique commentary for every date.
Confession notes remain in memory and clear when leaving or backgrounding the app.
Prayer favorites and Sunday reflections are stored on the device.

Native sharing captures a PNG and opens the system share sheet; web uses text
sharing. Rebuild the native app after installing the new native dependencies.

Rebuild calendar data with `node scripts/build-companion-calendar.mjs <source>`
where source is a checkout of cpbjr/catholic-readings-api pinned to the commit in
assets/CREDITS.md. Generated JSON is bundled so everyday use is offline.


## Widgets and calendar notices

The iOS widget gallery offers Daily Verse (existing rotation unchanged), Daily
Reading (today’s Gospel citation and opening verse in WEB-CE), and Verse Countdown.
Users can install both Scripture widgets together. Daily Reading uses local
Gregorian dates, provides midnight entries for seven days, handles year boundaries,
and links to `/daily?date=YYYY-MM-DD`. Beyond reference coverage it shows the
calendar observance with a link to the readings; it never reuses yesterday’s Gospel.
Run `bun run build:daily-reading-widget` after rebuilding calendar/Bible data.
The year-sized JSON resources are automatically bundled by the extension’s Xcode
synchronized folder. Calendar: United States Roman Rite.

Settings → Calendar notifications lets users opt in and choose a time (8 AM by
default). One local notice per day names the calendar observance and Gospel
reference. Schedules replenish on launch, foregrounding and hourly while active,
up to 30 days ahead, reserving capacity for other reminders. Users must reopen the
app at least monthly and after time-zone changes. No push server is required.
Disabling these notices preserves Rosary reminders. Notification taps open the
original notice’s dated readings.

Implementation references: [WidgetKit timelines](https://developer.apple.com/documentation/widgetkit/timeline)
and [Expo notifications](https://docs.expo.dev/versions/latest/sdk/notifications/).
The icon was generated with the built-in image tool; its exact prompt is in
`prompts/john-icon-chi-rho.txt`.
