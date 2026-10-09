# Outreach

Letting Catholic communities know a free Bible app exists, without turning it
into a marketing campaign.

## What this is, and what it is not

Lock Bible is free, has no ads, no accounts, no subscription and no analytics
funnel. There is nothing to sell. So these messages offer a resource and then
get out of the way. They do not ask for a review, a video, a shoutout, a link,
or a reply.

**No personal credit.** The messages are signed "the maintainer" and name
nobody. If a recipient ever mentions the app to their audience, there is
genuinely nothing to credit — it is a free app on the App Store, and the
listing shows North Boutique Studios Ltd, not a person.

**What we will not do.** We do not ask anyone to tell their audience they
discovered the app on their own. That would put a false impression in front of
people who trust them, and for a YouTube or Instagram creator an undisclosed
approach from the developer is also their problem, not just ours. Asking for no
credit is easy and honest. Asking someone to misrepresent how they found
something is neither, and it is the kind of thing that turns into a story.

## Rules

1. **Publicly listed contact routes only.** An address the person published, a
   contact form, a press page. Nothing scraped, guessed or constructed.
2. **Never bypass a CAPTCHA.** YouTube hides most channel emails behind one.
   Those channels are recorded with `contactRoute: youtube-about-captcha` and
   no email. Reach them another way or not at all.
3. **One message per contact.** No sequences, no follow-ups, no "just bumping
   this". If they do not reply, that is the answer.
4. **Personalised or not sent.** Every message names something specific and
   true about that channel. If the research did not turn up anything specific,
   the contact is dropped rather than padded with flattery.
5. **Nothing sends itself.** `make-drafts.py` writes Gmail *drafts*. A human
   opens each one, reads it, and decides. There is no send path in this repo.
6. **Small batches.** Twenty thoughtful notes beat four hundred. Bulk identical
   mail to people who did not ask for it is spam whatever it is offering.

## Files

| File | What it is |
| --- | --- |
| `contacts.json` | Researched contacts with their public route and why they fit |
| `templates.md` | The message bodies, with personalisation slots |
| `make-drafts.py` | Renders a personalised draft per contact into Gmail Drafts |
| `sent-log.json` | What has actually gone out, so nobody is contacted twice |

## Using it

```bash
python3 marketing/outreach/make-drafts.py --dry-run          # print, write nothing
python3 marketing/outreach/make-drafts.py --limit 10         # 10 drafts into Gmail
python3 marketing/outreach/make-drafts.py --only ascension-press
```

`--dry-run` first, always. Read a few in full. The drafts land in Gmail unsent;
send the ones that read well and delete the ones that do not.
