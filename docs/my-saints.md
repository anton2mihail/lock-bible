# My Saints

My Saints adds personal saint pages, native widgets, and feast preparation to iOS and Android. Open it from Today or Pray. Mapped results in Saints & feast days also open a personal page.

## Catalog

`src/services/companion/data/my-saints.json` is the shared catalog. It starts with Joseph, Thérèse of Lisieux, Jude, Benedict, Monica, Francis of Assisi, Anthony of Padua, Anne, and Pio of Pietrelcina.

Each stable saint ID has explicit links to existing calendar entries. An entry can name a group or a separate commemoration. The app does not merge entries by name. The page shows the selected calendar and its source. Parish calendars and transferred feasts can differ.

The original life excerpt or summary stays in `account`. An optional `reviewedSummary` can provide a shorter summary with the same source. The first short summary is for Joseph on March 19.

Artwork comes from the existing credited collection. Thérèse and Pio have no portrait in this catalog: their current devotional assets depict the Holy Face and Sacred Heart. Do not use those images as portraits.

## Personal pages

- Save or remove a saint from My Saints.
- Read the sourced life account.
- Open an existing linked novena. The app keeps its progress.
- Save a private reason, intention, or note of thanks.
- Delete individual notes.
- Open feast preparation or widget setup.

Notes use local app storage. They do not enter widget content or notification text. Removing a saved saint keeps notes, prayer progress, reminders, and widget choices. When a reminder remains enabled, the removal dialog explains this.

The iOS state adds an optional `saints` field. Older state files still decode. Android uses dedicated keys in the existing local store. Both platforms publish a change only after storage reports success.

## Widgets

iOS provides small and medium Home Screen widgets and a rectangular Lock Screen widget. Android provides a widget that changes layout with its width. Each widget can select a saint. An unconfigured widget can use the app's saved choice.

The quiet option shows artwork and the name. Standard content uses the existing Joseph novena response or a sourced life excerpt. A selected commemoration shows “Remembered today.” Tapping opens that saint's page. It does not complete a prayer.

The iOS shared container holds public catalog content, artwork, fonts, and widget choices. It does not receive the private profile. Missing portraits use text. Lock Screen and tinted rendering do not depend on a color portrait.

The user adds the widget through the operating system. The app provides setup instructions. Refresh timing remains under operating system control.

## Feast preparation and reminders

A plan records a particular annual occurrence. It appears on Today during the nine days before that date. A March 19 plan starts on March 10 and ends on March 18. Creating a plan does not complete days or reset an existing novena.

Changing the commemoration cancels the old plan when the user saves settings. Saints without a linked novena show their available life account and prayer library.

Feast reminders start disabled. Saving an enabled reminder requests notification permission. The screen reports a denied request or a failed save. The next reminder date is shown with its local time.

On iOS, the existing notification service reserves capacity for personal feast reminders before it fills the rolling calendar schedule. A personal reminder replaces a general calendar alert at the same date and time. A failed schedule or state save restores the previous schedule. Foreground refresh recalculates the next annual occurrence and time zone.

On Android, each saint has a separate alarm. The receiver schedules the next annual occurrence. App start, reboot, and clock or time zone changes refresh alarms. Android can delay these inexact alarms to save battery. The general calendar receiver suppresses a matching personal reminder.

## Validation

The implementation has:

- Core tests for old state, calendar mappings, private widget data, local dates, leap years, and the nine-day plan.
- A notification service harness for permission denial, duplicate suppression, schedule failure, commit failure, capacity, disable, and annual refresh. Run `python3 scripts/native/tests/test-my-saints-notices.py`.
- An iOS UI test for saved saints, notes, and feast plans across app launches.
- Android UI tests for persisted notes, removal without note loss, and planning without completing prayers.
- An Android widget-host test for the portrait, small and medium layouts, public prayer content, and the tap destination.

Checks on October 20, 2026 passed: both native builds, 50 Swift core tests, 21 Android unit tests, one iOS persistence UI test, three Android device tests, and the notification failure harness. Android lint reported no errors. The iOS Home Screen widgets were also added and opened in the simulator. Personal pages and feast preparation were checked against the approved design.

Before a store release, check physical-device notification delivery, accessibility text sizes, iOS Lock Screen and tinted widgets, and Android launcher resize behavior.
