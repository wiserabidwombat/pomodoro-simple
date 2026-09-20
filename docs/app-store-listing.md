# App Store Connect listing — Simple: StandBy Timer

Paste these into the corresponding App Store Connect fields when you create
the app record. Character limits are Apple's current hard limits.

## Name (30 char limit)
Simple: StandBy Timer

## Subtitle (30 char limit)
Focus timer for your Lock Screen

## Promotional text (170 char limit, editable any time without a new build)
A Pomodoro timer built for the Lock Screen, StandBy, and the Dynamic Island —
start a Focus session and control it without ever unlocking your phone.

## Description
Simple: StandBy Timer is a focus timer built around the classic Pomodoro Technique:
25 minutes of focused work, then a short break, repeating in a cycle with a
longer break every 4th round.

What makes it different is where it lives. Once you start a session, you
never need to keep the app open:

- Control Pause, Resume, and Skip right from the Lock Screen Live Activity
- See your countdown and controls in the Dynamic Island
- Dock your phone in StandBy and read the timer from across the room
- Add a Home Screen or Lock Screen widget for an always-visible countdown

Simple, focused features:
- A clean, distraction-free timer with a clear view of where you are in the
  4-session cycle
- A Stats screen that tracks how many focus sessions you complete, today and
  all-time
- 7 accent colors to make it yours
- A Restart button for when you need to start the cycle over
- A short in-app guide explaining how the cycle works

No accounts. No ads. No tracking. No subscription. Just a focus timer that
works where you actually spend your time.

## Keywords (100 char limit, comma-separated, no spaces needed)
pomodoro,focus timer,productivity,study timer,standby,live activity,widget,work timer,break timer

## Support URL
https://github.com/wiserabidwombat/pomodoro-simple/issues

## Marketing URL (optional)
https://github.com/wiserabidwombat/pomodoro-simple

## Privacy Policy URL
https://wiserabidwombat.github.io/pomodoro-simple/privacy-policy/

## Category
Primary: Productivity

## Age Rating
Answer "No" to every content questionnaire item (no objectionable content of
any kind) → results in 4+.

## Pricing
Tier 1 ($0.99 USD, localized equivalents elsewhere)

## App Privacy ("Nutrition Label") questionnaire
Answer **"No, we do not collect data from this app"** for all categories —
this matches `PrivacyInfo.xcprivacy` and the actual behavior of the app (no
network calls, no accounts, no analytics, no third-party SDKs).

## Copyright
© 2026 Aaron Tilley

---

## Manual steps still required in App Store Connect (not something I can do
for you — these need your Apple ID / account actions):

1. Accept the Paid Applications Agreement and complete banking/tax info,
   under Agreements, Tax, and Banking.
2. Create a new app record using bundle ID `com.aarontilley.pomodoro`.
3. Paste in the fields above.
4. Upload the app icon (already updated in the asset catalog) and the
   screenshots from `docs/app-store/screenshots/`.
5. Archive the app in Xcode (Product → Archive) and upload the build via the
   Organizer (or Transporter).
6. Select the uploaded build on the app record, finish the remaining
   required fields App Store Connect prompts for, and submit for review.
