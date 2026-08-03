# Publishing Checklist for Draft It!

This folder contains free GitHub Pages site pages you need for App Store submission:
Apple requires a **Support URL** and a **Privacy Policy URL** for every app, even one
that stores nothing.

## 1. Host the pages (free, ~5 minutes)

Option A — Same repo (easiest):
1. Push this repo to GitHub (it already points at `DYitaoW/Soccer-Draft-App`).
2. In GitHub → repo → Settings → Pages → Source: `Deploy from a branch`, branch `main`, folder `/Publishing/support` → Save.
3. Repeat, switching the folder to `/Publishing/privacy` for the privacy page, OR
   deploy `/Publishing` as a folder site and use paths `/privacy/` and `/support/`.

Recommended: deploy the repo root, then your URLs are:
- Privacy Policy: `https://DYitaoW.github.io/Soccer-Draft-App/Publishing/privacy/`
- Support:        `https://DYitaoW.github.io/Soccer-Draft-App/Publishing/support/`

Option B — Separate dedicated repo:
1. Create a new repo e.g. `draft-it-site`, push the `privacy/` and `support/` folders.
2. Settings → Pages → deploy from `main` branch.
3. URLs become `https://<username>.github.io/draft-it-site/privacy/` etc.

## 2. Update the contact email

The pages currently use a placeholder `you@example.com`. Open both HTML files and
replace it with a real email address you can receive mail at.

## 3. Paste URLs into App Store Connect

In App Store Connect → your app → App Information (or the app version's "App Review"):
- **Privacy Policy URL** → your privacy page URL
- **Support URL** → your support page URL

## 4. App Store Connect Privacy questionnaire

Because the app collects no data and ships with `PrivacyInfo.xcprivacy` declaring
nothing, answer:
- Data collected: **No**
- Tracking: **No**

## 5. Remaining manual steps (can't be automated from here)

- Upload a real 1024×1024 app icon (the current one is a screenshot).
- Add the paid Apple Developer Program membership ($99/yr) if not already active.
- Take 6.5"/6.7" screenshots, write description/keywords in App Store Connect.
- Build an Archive (Product > Archive) and upload via Xcode Organizer / Transporter.
