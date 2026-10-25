# John 1:1 — expansion and polish ideas (2026-10-25)

Ideas, not decisions. Ranked by effect on the two goals in `store-conversion-and-first-unlock-plan.md`:
more downloads from App Store search, and the first sales of the Fathers library. Review date: 2027-01-31.

Facts this rests on: every visit comes from App Store search; page-to-download conversion was 1.61%;
the page shows no ratings; revenue was $0 before 2.1.0; the app is 159 MB; Android has almost no users.
Promise to keep: no account, no ads, no subscription, offline, public-domain or properly licensed text only.

## Tier 1 — do before Advent (starts Sunday 29 November 2026)

1. **Advent In-App Event + Advent content.** In-App Events appear in App Store search and on the product page,
   free. Add an Advent path: the O Antiphons (17–23 Dec), a daily Advent reading with a Father's comment, and an
   Advent wreath prayer. The 2.0.1-era event draft in App Store Connect shows the mechanism works. Repeat for Lent
   (Ash Wednesday 10 February 2027). Expected effect: impressions in the season when Catholic searches peak.
2. **Today's Gospel with the Fathers (Catena Aurea).** St Thomas Aquinas's verse-by-verse chain of the Fathers
   on all four Gospels; the 1841 Newman translation is public domain. Show one passage free on Today under the
   daily Gospel, with "Read all the Fathers on this Gospel" leading to the library. This connects the free daily
   habit to the paid library every single day. Add it to the paid library as its own work.
3. **Ratings.** The prompt shipped in 2.1.0. Also: ask the 118 researched outreach contacts for honest reviews
   only if the outreach rules allow; otherwise rely on the prompt. Ten ratings change the product page.
4. **Custom product pages for each search intent.** Separate pages for "Douay-Rheims", "Latin Vulgate",
   "Rosary", "Saints", "Church Fathers", each with its first screenshot showing that thing. Apple lets keywords
   point at a page (the By Day pages show the method).

## Tier 2 — reach more people (December–January)

5. **Spanish, fully.** About 40% of US Catholics are Hispanic. The store says "English and Spanish", but the
   Bible is English and Latin only. Add the Torres Amat Catholic Bible (1825, public domain), Spanish prayers
   (Padre Nuestro, Ave María, the Rosary), a Spanish UI and a Spanish store listing and screenshots.
6. **Smaller download.** 159 MB hurts conversion on cellular. Move the Fathers library (most of the size) to
   Apple On-Demand Resources / Background Assets and Play Asset Delivery; free sample sections ship in the app,
   the rest downloads once. Paid users get it in the background.
7. **Mac.** The page says "Not verified for macOS". Verify the iPad app on Apple silicon Macs and it appears in
   Mac App Store search: a second shelf for free.
8. **Android parity and listing.** Bring 2.1.1's interface changes to Android, replace the Play screenshots
   with the new set, and point Play's description at the Fathers library. Android is tiny today; keep it in step
   but do not lead with it.

## Tier 3 — daily prayer depth (keeps people opening the app)

9. **Night Prayer (Compline)** first, then morning and evening prayer, from a public-domain breviary translation
   or the Little Office of the Blessed Virgin Mary. The modern Liturgy of the Hours English text is copyrighted
   (ICEL); check every source's licence before shipping. Laudate's reviews ask for exactly this.
10. **Stations of the Cross** (St Alphonsus Liguori, public domain) with the Stations paintings, prominent in Lent.
11. **Daily Examen** (St Ignatius, Spiritual Exercises), five short steps at night, with an optional reminder.
12. **Angelus at noon** (Regina Caeli in Eastertide): a local notification that opens the prayer. Already in the
    prayer library; only the reminder is new.
13. **Reading plans across the library:** "The Confessions in 40 days", "The Sermon on the Mount with Augustine",
    "Lent with Chrysostom". Plans make the paid library feel like a guide, not a heap of books.

## Tier 4 — platform features that set it apart

14. **Apple Watch Rosary.** A decade counter on the wrist with a haptic tap per bead, no phone needed. Few Catholic
    apps do this well, and it is a natural App Store feature candidate.
15. **CarPlay / audio Rosary.** Many people pray the Rosary while driving. On-device speech already reads text
    aloud; an audio session that CarPlay can show turns the commute into a use case.
16. **Control Center and StandBy.** A "Pray the Rosary" control and a StandBy verse view.
17. **Siri and Shortcuts:** "Read today's Gospel", "Start the Rosary", "Verse of the day" (App Intents exist; extend
    them and add Spotlight-able prayers).

## Tier 5 — more to sell, later (only after the first library sales)

18. **Second pack, "Spiritual Classics":** The Imitation of Christ, Introduction to the Devout Life, Story of a Soul
    (1912 translation), the Little Flowers of St Francis, Butler's Lives of the Saints. All public domain in the US.
19. **Haydock Douay-Rheims commentary** (1859, public domain): verse notes inside the Douay reader. Strong for the
    traditional readers who already search "Douay-Rheims".
20. **Complete bundle** of all packs at a discount, and a one-time **tip jar** ("Support John 1:1") for people who
    want to give without buying content.
21. **Offer codes for parishes and OCIA groups:** Apple and Google both support one-time-use codes for in-app
    purchases. A parish can give the library to every catechumen. Outreach to parishes, not just individuals.

## Polish pass (small, many)

- **First launch:** a three-step welcome (choose edition, add the Lock Screen widget, optional daily reminder).
  Today the widget, the app's original selling point, is hidden in Settings.
- **Empty states:** every list that can be empty (Saved, My Saints, plans) gets one sentence and one button.
- **Reader:** remember position per edition; "jump to verse" from the chapter title; highlight colours in dark mode
  checked for contrast.
- **Accessibility:** a full VoiceOver pass of the Rosary guide and the paged reader; the largest text size on
  every screen (2.1.1 fixed the Read tab and Settings only).
- **Store page:** a 15-second preview video (paged reader, Rosary, Lock Screen), the What's New text written for
  people, and the support page on its own domain instead of a GitHub Pages URL.
- **Quality signals without tracking:** watch App Store Connect crashes and Play vitals weekly; the app has no
  analytics by promise, so these are the only numbers.

## Suggested order

| When | Work |
|---|---|
| Now to 22 Nov | Catena Aurea on Today (2), Advent content and In-App Event (1), custom product pages (4) |
| Dec | Spanish (5), smaller download (6), Mac verification (7) |
| Jan | Android parity (8), Compline and Examen (9, 11), library reading plans (13) |
| After first sales | Watch Rosary (14), second pack (18), parish codes (21) |
