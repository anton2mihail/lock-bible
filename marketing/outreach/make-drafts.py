#!/usr/bin/env python3
"""Render one personalised outreach message per contact.

This script writes text. It has no send path and no mail credentials, by
design: it renders `outbox.json`, which a human then reviews before anything
becomes a Gmail draft, and nothing becomes a sent message without a person
clicking send.

    python3 marketing/outreach/make-drafts.py --dry-run
    python3 marketing/outreach/make-drafts.py --limit 10
    python3 marketing/outreach/make-drafts.py --only ascension-press

A contact is skipped, loudly, if it has no public email, if it is already in
`sent-log.json`, or if the research did not give us something specific to say.
That last rule is the important one: a template with an empty personalisation
slot is a form letter, and a form letter to someone who did not ask for it is
the thing this outreach is trying not to be.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
CONTACTS = HERE / "contacts.json"
SENT_LOG = HERE / "sent-log.json"
OUTBOX = HERE / "outbox.json"

APP_URL = "https://apps.apple.com/us/app/john-1-1-lock-bible/id6784763639"
SIGNATURE = "— the maintainer, Lock Bible"

# Which template each kind of contact gets.
TEMPLATE_BY_PLATFORM = {
    "youtube": "creator",
    "instagram": "creator",
    "podcast": "creator",
    "tiktok": "creator",
    "diocese": "parish",
    "order": "parish",
    "parish": "parish",
    "ministry": "parish",
    "school": "educator",
    "educator": "educator",
    "newsletter": "media",
    "website": "media",
    "blog": "media",
    "magazine": "media",
}

TEMPLATES = {
    "creator": {
        "subject": "A free offline Catholic Bible app, in case it's useful",
        "body": """Hello {name},

{specific}

I maintain a free Catholic Bible app called Lock Bible, and I'm writing for one reason only: so you know it exists.

It's free, with no ads, no account, no subscription and nothing to unlock. The whole Bible, the Rosary and a set of novenas work with the phone in airplane mode. There's a Lock Screen widget that puts a verse in front of you during the day, which is the part most people end up using.

{url}

I'm not asking for a mention, a review, or a reply. If it's useful to you or to the people who follow you, that's the whole point. If you ever did mention it, please don't credit me or anyone — there's nothing to credit. It's just a free app on the App Store.

If it's not for you, no reply needed at all, and I won't write again.

{signature}""",
    },
    "parish": {
        "subject": "A free offline Bible app for your resource lists",
        "body": """Dear {name},

{specific}

I maintain a free Catholic Bible app, Lock Bible, and I thought it might be worth passing on.

The reason I mention it for parish use in particular: everything works offline. The full Bible, the Rosary, the Seven Sorrows, and a set of novenas are on the phone itself, so it works in a church basement, on retreat, or anywhere the signal doesn't reach. There's no account to create, nothing to pay for, no ads, and it collects nothing about the people using it.

{url}

Please feel free to pass it on or add it to a resource list if it's useful. No attribution is wanted or needed. If it isn't a fit, no reply necessary.

{signature}""",
    },
    "educator": {
        "subject": "A free offline Bible app, no accounts, for classroom use",
        "body": """Hello {name},

{specific}

I maintain a free Catholic Bible app called Lock Bible. I'm sending it your way because of one thing that tends to matter in a classroom or at home: there is no account, no sign-in, no ads and no data collection, and the whole Bible works offline. Nothing asks a student for an email address.

{url}

It's free and will stay free. No credit needed if you share it — it's just an app on the App Store. No reply needed either.

{signature}""",
    },
    "media": {
        "subject": "Free offline Catholic Bible app, for your resource coverage",
        "body": """Hello {name},

{specific}

Lock Bible is a free Catholic Bible app: the full Catholic canon, the Rosary including the Servite Seven Sorrows, novenas, the liturgical calendar and daily readings, all working offline, with no ads, no account, no subscription and no tracking.

{url}

Happy to answer anything factual about it. I'd rather not be named or quoted personally — there's no story here beyond a free app that works. Ignore this freely if it isn't relevant.

{signature}""",
    },
}

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$")


def slugify(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def salutation(name: str) -> str:
    """Trim a research label down to something you can address a letter to."""
    name = re.sub(r"\s*\([^)]*\)", "", name)          # drop "(Fr. Mike Schmitz, ...)"
    name = re.split(r"\s+[—–-]\s+", name)[0]           # drop " — Communications Office"
    return name.strip(" ,;:")


def personalisation(contact: dict) -> str | None:
    """The one researched, specific opening line, or None if we do not have one."""
    specific = (contact.get("specific") or "").strip()
    if not specific:
        return None
    if not specific.endswith((".", "!", "?")):
        specific += "."
    return specific


def render(contact: dict) -> dict | None:
    platform = (contact.get("platform") or "").lower()
    template = TEMPLATES[TEMPLATE_BY_PLATFORM.get(platform, "creator")]
    specific = personalisation(contact)
    if not specific:
        return None
    return {
        "slug": contact.get("slug") or slugify(contact["name"]),
        "to": contact["email"],
        "name": contact["name"],
        "platform": platform,
        "subject": template["subject"],
        "body": template["body"].format(
            name=salutation(contact["name"]), specific=specific,
            url=APP_URL, signature=SIGNATURE,
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="print, write nothing")
    parser.add_argument("--limit", type=int, help="render at most this many")
    parser.add_argument("--only", nargs="*", metavar="SLUG")
    args = parser.parse_args()

    if not CONTACTS.exists():
        print(f"missing {CONTACTS}", file=sys.stderr)
        return 1
    contacts = json.loads(CONTACTS.read_text())
    already = set(json.loads(SENT_LOG.read_text())) if SENT_LOG.exists() else set()

    rendered, skipped = [], []
    for contact in contacts:
        slug = contact.get("slug") or slugify(contact.get("name", ""))
        if args.only and slug not in args.only:
            continue
        email = (contact.get("email") or "").strip()
        if not EMAIL_RE.match(email):
            skipped.append((slug, f"no public email (route: {contact.get('contactRoute', '?')})"))
            continue
        if slug in already:
            skipped.append((slug, "already contacted"))
            continue
        message = render(contact)
        if not message:
            skipped.append((slug, "nothing specific to say — research it or drop it"))
            continue
        rendered.append(message)
        if args.limit and len(rendered) >= args.limit:
            break

    for slug, reason in skipped:
        print(f"  skip  {slug}: {reason}")
    print(f"\n{len(rendered)} message(s) rendered, {len(skipped)} skipped.")

    if args.dry_run:
        for message in rendered:
            print("\n" + "=" * 72)
            print(f"To: {message['to']}\nSubject: {message['subject']}\n")
            print(message["body"])
        return 0

    OUTBOX.write_text(json.dumps(rendered, indent=2, ensure_ascii=False) + "\n")
    print(f"→ {OUTBOX.relative_to(HERE.parent.parent)}")
    print("Review it, then have these turned into Gmail drafts. Nothing is sent by this script.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
