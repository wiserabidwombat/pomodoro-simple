# pomodoro-simple

A Pomodoro timer for iOS designed to sit on your desk or nightstand in
StandBy mode, with the countdown and controls on your Lock Screen and in the
Dynamic Island too. Built as **Simple: StandBy Timer**.

I built this app because I wanted a Pomodoro app I could control from the
StandBy screen, that didn't require a subscription and was simple to use.

> **Availability:** In public beta on TestFlight. Join here:
> **[testflight.apple.com/join/GYzhgfF5](https://testflight.apple.com/join/GYzhgfF5)**
>
> You'll need an iPhone or iPad on iOS 17 or later and Apple's free
> [TestFlight app](https://apps.apple.com/app/testflight/id899247664).
> Feedback is welcome: take a screenshot in the app and TestFlight will offer
> to send it to me.

More screenshots and the story behind the app: [aarontilley.me/projects/pomodoro-simple](https://aarontilley.me/projects/pomodoro-simple).
Privacy policy: [everything stays on your phone](https://aarontilley.me/projects/pomodoro-simple/privacy).

## Features

- **StandBy and Dynamic Island.** A running session shows in StandBy and the
  Dynamic Island, so you can check and control the timer without opening the
  app.
- **Live Activities.** The Lock Screen shows a live countdown with
  Pause/Resume/Skip buttons, in your accent color on black.
- **Home Screen and Lock Screen widgets.** Home Screen widgets show the
  current phase and countdown, with a Start button when idle and
  Pause/Resume and Skip while running. A round Lock Screen widget shows a
  progress ring that drains as the phase runs.
- **iPad.** A big timer with a progress ring, plus cards for today's
  progress, what's up next, this week, and your profile, beside it in
  landscape and below it in portrait. Desk Mode shows just the ring, the
  countdown, and the time of day, full screen, and a floating Picture in
  Picture countdown stays on screen over other apps. Every orientation, Split
  View and Slide Over, and keyboard shortcuts: Space to start, pause, and
  resume, S to skip, ⌘R to restart, ⌘D for Desk Mode, ⇧⌘P for the floating
  timer, and ⌘1–⌘3 to switch screens. Live Activities and StandBy are iPhone-only.
- **Timer profiles.** Save different setups, each with its own Focus, Short
  Break and Long Break lengths and number of sessions before a Long Break.
  Comes with Classic (25/5/15, Long Break after 4) and Deep Work (50/10/30,
  Long Break after 2).
- **Siri, Shortcuts and the Action Button.** "Start Deep Work with Simple
  Timer" starts that profile, and a Start Timer Profile shortcut can go on
  the Action Button of newer iPhones.
- **Finish early.** Done with a Focus session before the timer? Past the
  halfway mark, "Finish & Count It" records the time you actually focused.
- **Daily goal.** Set a number of Focus sessions per day and track it on the
  Timer screen, the medium widget and in Stats.
- **Stats.** Today's count, all-time total, streaks, total focus time, a
  last-7-days chart and a per-day history, for all profiles together or one
  at a time.
- **Export history.** Share every session (date, profile, length) as a CSV
  file from Stats.
- **Keep Screen Awake.** Optionally stops the phone from locking while the
  Timer screen is open, for when it's propped on a desk without StandBy.
- **Accent colors.** Choose from 7 preset colors or pick a custom one; the
  buttons and tab bar follow your color.
- **Accessibility.** VoiceOver labels throughout and support for the largest
  text sizes.
- **Notification permission primer.** On first launch, a screen explains what
  notifications are for before iOS asks for permission.
- **Shared state via App Groups.** The app, widgets and Live Activity all
  read and write the same timer state through a shared App Group.
- **No subscription, no account, no tracking.**

## Screenshots

| Timer | Live Activity | StandBy |
| --- | --- | --- |
| <img src="docs/screenshots/timer.png" width="200" alt="Timer screen mid-session with cycle progress"> | <img src="docs/screenshots/live-activity.png" width="200" alt="Live Activity countdown in the Dynamic Island above a small Home Screen widget"> | <img src="docs/screenshots/standby.png" width="360" alt="StandBy mode showing the timer in landscape with Pause and Skip buttons"> |

| Widget | Settings |
| --- | --- |
| <img src="docs/screenshots/widget.png" width="200" alt="Medium Home Screen widget with countdown, Pause and Skip buttons, cycle progress and today's count"> | <img src="docs/screenshots/settings.png" width="200" alt="Settings screen with accent colors, durations and sound options"> |

## Tech stack

Swift · SwiftUI · WidgetKit · ActivityKit · App Intents · SwiftData · Swift
Charts · UserNotifications · XcodeGen (project generation) · XCTest

## How I built it

Developed with [Claude Code](https://claude.com/claude-code). I gave Claude a
fairly open prompt describing most of the functionality I wanted, then let it
do its thing to see what would or could happen.

## Building it yourself

### One-time setup (before first build)

This repo is already configured with the bundle id `com.aarontilley.pomodoro`
and matching App Group `group.com.aarontilley.pomodoro` — if you're building
this exact repo under that same Apple Developer account, skip straight to
step 4.

If you're forking this for your own Apple Developer account instead, pick
your own reverse-DNS bundle id (e.g. `com.yourname.pomodoro`) and replace
`com.aarontilley.pomodoro` everywhere it appears first:
   - `project.yml` (`bundleIdPrefix`, both `PRODUCT_BUNDLE_IDENTIFIER` values)
   - `Pomodoro/Pomodoro.entitlements` and `PomodoroWidget/PomodoroWidget.entitlements`
     (the `group.com.aarontilley.pomodoro` App Group id — keep the `group.` prefix)
   - `Shared/AppGroup.swift` (`identifier`)

1. Install tools: `brew install xcodegen imagemagick`
2. In [Apple's developer portal](https://developer.apple.com/account/resources/identifiers/list),
   register an App Group with the exact id above, and register it as a
   capability on both the app and widget extension App IDs (or let Xcode's
   "Automatically manage signing" register it for you in step 5 below).
3. Enroll in the paid Apple Developer Program if you haven't already — App
   Groups require it; a free/personal-team account can't use them at all.
4. Run `xcodegen generate`, then open `Pomodoro.xcodeproj` in Xcode.
   `Pomodoro.xcodeproj` is generated and git-ignored, so re-run
   `xcodegen generate` whenever you pull changes that add, remove, or move
   Swift files.
5. In Xcode, select your Team for both the `Pomodoro` and
   `PomodoroWidgetExtension` targets under Signing & Capabilities, and
   confirm the App Groups capability shows your group id on both targets.
   If building for a physical device for the first time, also register the
   device under your team (Xcode usually offers to do this automatically
   once you pick it as the run destination).

## Xcode Cloud

`Pomodoro.xcodeproj` isn't committed, so `ci_scripts/ci_post_clone.sh`
installs XcodeGen and runs `xcodegen generate` right after Xcode Cloud clones
the repo. Xcode Cloud also assigns its own build numbers when it archives, so
the `CFBundleVersion` in the Info.plists only matters for manual uploads from
Xcode's Organizer.

## Testing

Unit tests live in `PomodoroTests/` and run from the `Pomodoro` scheme. The
widget, Live Activity and StandBy visuals can't be unit tested; see the
[manual testing checklist](TESTING.md) and run through it on a real device.
