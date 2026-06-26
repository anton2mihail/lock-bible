# NRSVCE Licensing Inquiry

This is a ready-to-send inquiry for licensing the **NRSV Catholic Edition**
(or its successor, the **NRSVue Catholic Edition**) for use as the bundled text
of this mobile app.

## Why this is needed

The NRSV/NRSVCE is **not** public domain and is **not** available through any
public Bible API. The only legal way to ship its text in an app is a negotiated
license from the rights holder, the **National Council of the Churches of Christ
in the USA (NCC)**, administered by its rights agents. (The app currently ships
the public-domain **World English Bible — Catholic Edition** as a fully legal
default; NRSVCE can be swapped in once a license is signed — see
`docs/ARCHITECTURE.md` → "Swapping the translation".)

## Who to contact

| Contact | Email | Role |
|---|---|---|
| **Petradi International Rights Services** | `NCCrights@petradirights.com` | Primary agent named on the official NRSVCE site |
| Riggins Rights Management | `NRSVcopyright@rigginsrights.com` | Administers the broader NRSV/NRSVue program (cc) |
| Scribe Inc. | `bibles@scribenet.com` | Delivers the licensed text files *after* a license is granted |

> Note (2025–26): The plain NRSV is closed to new licenses; the **Catholic
> editions remain licensable**, and the program is transitioning to the
> **NRSVue-CE** (USCCB imprimatur reported granted Sept 2025). Ask which Catholic
> edition is currently open for new digital/app licenses.

---

## Draft email

**To:** NCCrights@petradirights.com
**Cc:** NRSVcopyright@rigginsrights.com
**Subject:** Licensing inquiry — NRSV Catholic Edition (or NRSVue-CE) for a mobile app

Dear Permissions Team,

I am developing a mobile application (iOS, with Android to follow) that presents
the Catholic canon of Scripture for daily reading, along with a daily/rotating
"verse of the day" feature including a lock-screen widget. I would like to
license the **New Revised Standard Version, Catholic Edition** — or the newer
**NRSVue Catholic Edition** if that is the edition currently open for new digital
licenses — as the in-app Bible text.

Details of the intended use:

- **Format:** Digital mobile application (iOS / Android). The full text would be
  bundled within the app for offline reading.
- **Scope:** The complete Catholic canon, including the deuterocanonical books.
- **Distribution model:** [Choose one — free to end users / paid app / freemium].
  I am happy to discuss whichever licensing tier fits.
- **Display:** Each screen showing Scripture will carry the required copyright
  notice and acknowledgment exactly as you specify.
- **Audience / scale:** [e.g., general public; initial launch in North America].

Could you please advise on:

1. Which Catholic edition (NRSV-CE or NRSVue-CE) is currently available for new
   **digital app** licenses?
2. The licensing terms and fee structure for full-text inclusion in a mobile app
   (one-time, royalty, and/or per-user/subscription models).
3. The required copyright notice and on-screen acknowledgment wording.
4. The process and timeline, including how the licensed text files are delivered
   (I understand this is handled by Scribe Inc. after a license is granted).

Thank you very much for your time. I want to ensure this app honors the text and
its rights holders fully and correctly, and I look forward to your guidance.

Kind regards,
[Your name]
[Company / project name]
[Contact email] · [Website / app listing if available]

---

## After a license is signed

1. Obtain the text files (ScML/XML, USFX, or similar) from Scribe Inc.
2. Add a new branch to `scripts/build-bible-data.mjs` that emits the same
   normalized JSON shape under a new translation id (e.g. `nrsvce`).
3. Register it in `src/services/bible/translations.ts`.
4. Set its `attribution`/`copyrightNotice` to the **exact** notice the license
   requires — these are already surfaced on the verse screen, reader, and
   settings "About" section.

No screen, widget, or routing code needs to change.
