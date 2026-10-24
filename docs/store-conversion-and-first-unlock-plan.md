# John 1:1 — store page conversion and first paid unlock

Written 2026-10-23. Owner: Anton. Review together with the By Day 90-day test on **2027-01-31**
(`ByDay-NB/Apps/BYDAY-90-DAY-TEST.md`).

## Why this app, why now

John 1:1 is the only North Boutique app that people find on their own. Nothing is behind it: no ads, no posts, no store page work since 1.x.

| Signal (iOS, 90 days to 2026-10-22) | Value |
|---|---|
| Impressions | 9.4K |
| Product page views | 319 |
| First-time downloads | 115 (+7 redownloads) |
| Page view to download | 1.61% |
| Traffic source | 100% App Store search |
| Ratings shown on the page | none ("not enough ratings") |
| Revenue | $0, no in-app purchase exists |
| Play, last 28 days | 2 device acquisitions |

Two levers, in this order:

1. **Conversion.** Make the store page say what the app is today. Target: 4% page view to download by 2027-01-31. Same impressions, 2.5x the downloads.
2. **First paid unlock.** One one-time purchase. Target: the first 10 sales by 2027-01-31. This is a test of whether this audience pays, not a revenue plan. At 40 downloads a month, even a 5% buy rate is 2 sales a month.

Everything below respects the app's promise: **no account, no ads, no subscription, offline.**

## What the store page says today, and what is wrong with it

Read from the public page and App Store Connect on 2026-10-23.

| Field | Today | Problem |
|---|---|---|
| Name | John 1:1 - Lock Bible (21 chars) | "Lock" puts the app next to screen-time and lock-screen apps. The page's "You might also like" row is BibleLock, WePray Prayer Lock, Lock Screen Loops. Hallow's row is Ascension, Laudate, Amen, iBreviary. We are in the wrong neighbourhood. |
| Subtitle | Daily Scripture, Fully Offline (30 chars) | Does not say Catholic, Rosary, readings or saints. |
| Category | Lifestyle | Every Catholic competitor is in Reference (Hallow #23, Laudate #135). |
| Promotional text | empty (170 chars free) | The one field that changes without a release, unused. |
| Description | Opens "Lock Bible puts Scripture… on your Lock Screen", lists the 1.x feature set only | Never mentions the Rosary, chaplets, daily Mass readings, the Church calendar, saints, novenas, Douay-Rheims, the Vulgate, or the 26 Fathers and Doctors (15.2 million words). It describes an app that no longer exists. |
| Keywords | 96 of 100 chars used, values not visible from the page | Read them in App Store Connect before any edit. |
| Screenshots | 5: "Turn the page, like a book", "Scripture on your Lock Screen", "Your Catholic day at a glance", "Walk with the Church year", "Make room for prayer" | Good art, soft captions. The first one does not say what the app is. "Catholic" appears first in screenshot 3. |
| Ratings | not enough to display | The app never asks. No `requestReview` call exists in `native/John`. |
| Requires | iOS 26.0 | Everyone on iOS 18 or earlier sees "requires iOS 26" and cannot install. Deployment target is 26.0 in the Xcode project. |
| Size | 159 MB | Fine. |
| Icon | Christ Pantocrator (Sinai) | Keep. Distinctive and right. |

## Part A — store page conversion

### A1. This week, no release needed

Anton saves every store edit himself after reading it (his standing rule). Agents draft.

1. **Promotional text (170 chars).** Draft:
   > The Catholic Bible, the Rosary, today's Mass readings, the saints and 15 million words of the Church Fathers. Offline. No account, no ads, no subscription.
   (Count before saving; trim "and" if over.)
2. **Description.** Rewrite so the first three lines, visible before "more", say what the app is now. Order: Bible in three editions (WEB Catholic Edition, Douay-Rheims, Clementine Vulgate) · Rosary, Seven Sorrows and chaplets · daily Mass readings on the US Roman calendar with the saint of the day · My Saints with novenas and feast reminders · the Fathers and Doctors library · lock-screen and home-screen widgets · private by design. Keep the honest limits that `docs/john/README.md` states: reading references cover 2026 and 2027; exact lectionary wording stays on USCCB. No "#1" claims. No competitor names.
3. **Keywords.** Read the live field first. Then replace with 100 chars that do not repeat words in the name or subtitle. Candidate (rules from `outreach/grok-bot/john-positioning.md`, extended):
   `catholic,rosary,douay,vulgate,novena,saints,mass readings,church fathers,augustine,aquinas,chaplet,lectio`
   Count and trim to 100. No spaces after commas. "lock screen" goes here only if D1 removes it from the name.
4. **Subtitle.** Change with the next version (needs a release). Recommended: **Catholic Bible, Rosary, Saints** (30 chars). It repeats "Bible" from the name, which costs one keyword slot, but a Catholic reads it and knows in one second that the app is for them. Alternative for a later test: **Rosary, Saints, Daily Readings** (30 chars).

### A2. With the next release (2.1.0)

5. **Category.** Primary Reference, secondary Books. Needs a new version.
6. **Name (decision D1).** Recommended: **John 1:1 - Catholic Bible** (25 chars). The on-device name stays "John 1:1", so Guideline 2.3.8 is satisfied, as in 1.2.2. Keep "lock screen" in keywords so the old searches still find it. Watch downloads for four weeks after the change. If downloads fall by a third or more, revert the name.
7. **Screenshots.** Six, in this order, each caption a plain statement:
   1. Reader, Douay or WEB-CE page — "The Catholic Bible. Three editions. Offline."
   2. Today — "Today's Mass readings and the saint of the day"
   3. Rosary — "The Rosary, the Seven Sorrows, the chaplets"
   4. Lock Screen with the verse widget and a My Saint widget — "A verse on your Lock Screen"
   5. Works library — "26 Fathers and Doctors. 15 million words. Offline."
   6. A plain card — "No account. No ads. No subscription."
   Reuse the capture pipeline in `docs/native/` and the real paintings rule from the 2.0.2 set. Run Apple's Product Page Optimization with the current set as control and this set as treatment. At 9.4K impressions a quarter, the test will not reach significance quickly; judge by the 30-day conversion trend as well.
8. **Ask for a rating.** Add `AppStore.requestReview` after a meaningful moment: the third completed Rosary or novena day, or the seventh day the app was opened. At most once per 120 days (same rule as By Day). Never on first launch, never after a purchase screen. Needs a release. Ratings on the page are the single biggest conversion lever after the first screenshot.
9. **iOS version floor (decision D6).** Measure how much of the app needs iOS 26. If a day's work gets the target to iOS 18, do it in 2.1.0. If it needs more, note the cost here and leave it.

### A3. Later

- Spanish store listing (the app ships Spanish strings; the page says "EN + 1 More").
- An app preview video of the Rosary and the lock-screen widget, only after the screenshot test has an answer.

## Part B — the first paid unlock

### What stays free, forever

Everything a person needs to pray: the Bible in all three editions, the Rosary and chaplets, the prayer library, daily readings, the saints calendar, My Saints, novenas, and the verse widgets. Nothing that exists today for a praying person becomes paid.

### What becomes the unlock (decision D2)

Recommended: **The Fathers and Doctors library** as a one-time, lifetime purchase.

- It is the largest thing in the app and the hardest to copy: 26 authors, 271 works, 15.1 million words, offline, with 975 chapter cross-references.
- It is a bookshelf. People understand paying once for books. Verbum and Logos sell the same public-domain corpus for far more.
- Not having it costs a praying person nothing. The promise holds.
- Free sample stays: the library browses in full, the Apostolic Fathers and the *Confessions* read in full, every other work reads its first section, then shows the unlock.

Second choice, if Anton prefers to gate nothing: a one-time **Supporter** purchase ($4.99) that unlocks only a thank-you page and a supporter badge in Settings. Cheaper to build, measures goodwill, teaches less.

### Terms

- **Type:** non-consumable. Never a subscription. Family Sharing on.
- **Product id:** `com.nrsv.verse.fathers`. Display name: "The Fathers and Doctors". Price tier: **US$9.99** to start; change to $6.99 by price edit alone (no release) if there are no sales in the first 30 days with at least 100 downloads.
- **Existing users keep it free (decision D3).** StoreKit 2 `AppTransaction.shared.originalAppVersion` gives the version a person first downloaded. If it is below 2.1.0, the library stays unlocked. No account needed, no server, honest to the people who already have it.
- **Where the purchase is found:** Settings → "The Fathers and Doctors", the library's own tab, and every locked work. Apple rejected By Day twice under 2.1(b) because the reviewer could not find the purchase. Put it where a reviewer looks and say so in the review notes.
- **Restore Purchases** in Settings, and on the unlock page.

### Build (iOS first, 2.1.0)

Follow the repo rule: no entrance animations.

1. `JohnCore`: an `Entitlements` store. State: `unlocked` from (a) a current StoreKit transaction for the product, (b) `originalAppVersion < 2.1.0`. Cached in `UserDefaults` for offline starts. Widgets never read it.
2. `Platform/Store`: StoreKit 2 wrapper. `Product.products(for:)`, `purchase()`, `Transaction.currentEntitlements`, `Transaction.updates` listener started at launch, `AppStore.sync()` for Restore.
3. `Features/Works`: gate reading past the first section of a locked work. The gate is a plain page: title, one paragraph on what is included, the price from StoreKit (never hard-coded), Buy, Restore, and the sentence "Everything else in John 1:1 stays free. No subscription."
4. `Features/Settings`: the row, the restore button, and the "You already have this" state for grandfathered people.
5. App Store Connect: create the non-consumable, localized name and description, price, a review screenshot of the unlock page. The first in-app purchase on an app must be added to a version in the web UI and submitted with it (the API cannot, same as By Day). Review notes: where the purchase is, that existing users are grandfathered, and the sandbox tester to use.
6. Android follows in Android 2.1.0 with Play Billing, same product id as an INAPP non-consumable, after iOS is approved. About 3 agent-days.

Effort, iOS: about 4 to 6 agent-days including the screenshot set and the review prompt.

### Test before submission

- Sandbox purchase, restore on a second simulator, grandfathered path with an `originalAppVersion` of 2.0.3 (StoreKit configuration file), offline launch with a cached entitlement, Family Sharing flag set.
- The UI test in the repo style: open a locked work, buy in the sandbox, read past the gate, relaunch, still unlocked.

## Sequence

| When | What | Needs a release | Who |
|---|---|---|---|
| Week 1 (by 2026-10-30) | Promotional text, description, keywords; read current keywords first | No | Agent drafts, Anton saves |
| Week 1 | Decisions D1 to D6 | No | Anton |
| Weeks 2 to 3 | 2.1.0: unlock, grandfathering, Restore, rating prompt, new screenshots, category, subtitle, name | Yes | Agent builds, Anton submits |
| Week 3 | In-app purchase created and submitted with 2.1.0 | - | Agent prepares, Anton submits |
| Week 4 onward | PPO screenshot test running; price change if no sales | No | Agent watches weekly |
| 2027-01-31 | Review against targets, with the By Day test | - | Anton |

## Targets for 2027-01-31

| Metric | Today | Target |
|---|---|---|
| Page view to download | 1.61% | 4% |
| Ratings shown on the page | 0 | 10 or more, 4.5 or above |
| Paid unlocks | 0 | 10 |
| First-time downloads a month | about 40 | 100 |

If conversion does not move and there are no sales, the store page is not the problem and the next step is distribution, not more product.

## Decisions for Anton

| # | Decision | Recommended default |
|---|---|---|
| D1 | Rename to "John 1:1 - Catholic Bible" | Yes, with 2.1.0; revert if downloads drop a third in four weeks |
| D2 | What becomes paid | The Fathers and Doctors library, $9.99 one-time, with the free sample above |
| D3 | Existing users | Grandfathered by `originalAppVersion` |
| D4 | Rating prompt moment | Third completed Rosary or novena day, or seventh day opened; once per 120 days |
| D5 | Category | Reference primary, Books secondary |
| D6 | iOS version floor | Investigate one day; drop to iOS 18 if it fits |

## Rules that stay

- No account, no ads, no subscription, no analytics. Local notifications only.
- No competitor names in any store field. No "#1" claims. Do not mention NRSV.
- Anton saves store metadata himself. Agents draft and show the count.
- Store submit only when Anton asks.

## Log

- 2026-10-23: plan written from the live store page, App Store Connect, Play Console and the repo.
- 2026-10-23: Anton approved the plan with the recommended defaults for D1 to D6. Week-1 store text drafts in `docs/store-text-2026-10-23.md`.
