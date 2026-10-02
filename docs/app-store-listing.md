# App Store Connect listing — Steady: Focus Timer

Paste these into the corresponding App Store Connect fields when you create
the app record. Character limits are Apple's current hard limits.

## Name (30 char limit)
Steady: Focus Timer

## Subtitle (30 char limit)
Pomodoro on every screen

## Promotional text (170 char limit, editable any time without a new build)
New: a native iPad app with Desk Mode and a floating timer, and an Apple Watch app. Start a Focus session and control it from your Lock Screen, StandBy, or wrist.

## Description (4,000 char limit)
Steady is a focus timer built around the classic Pomodoro
Technique: 25 minutes of focused work, then a short break, repeating in a cycle
with a longer break every 4th round. Or save your own timer profiles, like Deep
Work or Study, each with its own lengths and cycle.

What makes it different is where it lives. Once you start a session, you never
need to keep the app open.

ON IPHONE
- Pause, Resume, and Skip right from the Lock Screen Live Activity
- See your countdown in the Dynamic Island
- Dock your phone in StandBy and read the timer from across the room
- Home Screen and Lock Screen widgets, including a progress ring and a large
  widget with your week at a glance
- Start any profile with Siri ("Start Deep Work with Steady"), a
  Shortcut, or the Action Button

ON IPAD
- A big timer with a progress ring, plus today's progress, what's up next,
  and your week, side by side in landscape
- Desk Mode: just the timer and the time of day, full screen, with the screen
  kept on
- A floating Picture in Picture timer that stays on screen while you use
  other apps
- Split View, Slide Over, and keyboard shortcuts

ON APPLE WATCH
- Start, pause, skip, and finish sessions from your wrist, kept in sync with
  your iPhone
- A Smart Stack card with a live countdown and controls

FOCUS FEATURES
- Finish early: past the halfway mark, end a Focus session and still count it
- A daily goal, with progress on the timer, in widgets, and in Stats
- Stats for every profile and overall: today, streaks, focus time, and the
  last 7 days, with CSV export of your full history
- 7 accent colors or any color you like, plus optional holiday themes
- Keep Screen Awake for a phone or iPad propped on your desk
- VoiceOver labels throughout and support for the largest text sizes

No accounts. No ads. No tracking. No subscription. Everything stays on your
own devices.

## Keywords (100 char limit, comma-separated, no spaces needed)
productivity,study,work,deep work,standby,live activity,widget,ipad,apple watch,break,concentration

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
Answer **"No, we do not collect data from this app"** for all categories.
This matches `PrivacyInfo.xcprivacy` and the app's actual behavior: no network
requests of its own, no accounts, no analytics, no third-party SDKs. Syncing
between an iPhone and its paired Apple Watch goes through Apple's Watch
Connectivity between the user's own devices, so it isn't data collection.

## App Review notes
Paste into "Notes" under App Review Information:

> The app uses the "audio" background mode only for its iPad floating timer
> (Picture in Picture). Picture in Picture requires an active playback audio
> session to keep the countdown window running while the user is in other
> apps. The app never records or plays audio. To try it on iPad: open the
> Timer tab, start a session, and tap the Picture in Picture button at the
> top right.

## Screenshots needed
- iPhone 6.9" (required), from `docs/app-store/screenshots/`
- iPad 13" (required now that the app supports iPad): the Timer in landscape
  with the cards, Desk Mode, and the floating timer over another app
- Apple Watch (required for the watch app): the timer screen, and the Smart
  Stack card if you like

## Copyright
© 2026 Aaron Tilley

---

## Manual steps still required in App Store Connect (not something I can do
for you — these need your Apple ID / account actions):

1. Accept the Paid Applications Agreement and complete banking/tax info,
   under Agreements, Tax, and Banking.
2. Create a new app record using bundle ID `com.aarontilley.pomodoro`.
3. Paste in the fields above.
4. Upload the screenshots listed under "Screenshots needed" (iPhone, iPad,
   and Apple Watch). The app icon comes from the asset catalog.
5. Builds come from Xcode Cloud: a merge to main builds and uploads to App
   Store Connect, the same build you've been testing in TestFlight.
6. Select the uploaded build on the app record, finish the remaining
   required fields App Store Connect prompts for, and submit for review.
