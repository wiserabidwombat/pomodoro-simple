# pomodoro-simple
My first iOS app and it's a pomodoro app.  The one I want to use.

## One-time setup (before first build)

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
5. In Xcode, select your Team for both the `Pomodoro` and
   `PomodoroWidgetExtension` targets under Signing & Capabilities, and
   confirm the App Groups capability shows your group id on both targets.
   If building for a physical device for the first time, also register the
   device under your team (Xcode usually offers to do this automatically
   once you pick it as the run destination).

## Manual testing checklist

Widget/Live Activity/StandBy visuals cannot be unit tested — run through this
on a real device (a simulator can approximate StandBy and the Dynamic Island,
but a physical device docked and charging in landscape is the real test):

- [ ] Start a session, background the app, confirm the Live Activity shows on
      the Lock Screen with a live countdown and the chosen accent color on black.
- [ ] Simulator: Features menu → StandBy, confirm landscape rendering.
- [ ] Physical device: dock/charge in landscape, confirm StandBy matches.
- [ ] Tap Pause, then Resume, then Skip from the Lock Screen/StandBy Live
      Activity while the app is backgrounded; reopen the app and confirm its
      UI reflects each change.
- [ ] On a fresh install, confirm the notification primer screen appears
      first, before the Help sheet and before the real system permission
      dialog. Tap "Not Now"; confirm the system dialog never appears and the
      app still runs a full session with foreground sound/haptic only.
- [ ] Delete and reinstall fresh again; this time tap "Enable Notifications"
      on the primer and confirm the real system dialog appears next, then
      deny it there; confirm the app still doesn't crash and runs normally.
- [ ] Toggle each of the 7 preset accent colors in Settings; confirm the Timer
      screen, idle widget, and Live Activity all pick up the new color.
- [ ] Let a work phase's countdown run out with the app foregrounded; confirm
      it auto-advances to a short break and the Stats screen's "Today" count
      increments by one.
- [ ] Add the idle widget to the Home Screen and to the Lock Screen; confirm
      tapping either opens the app.
- [ ] From the Home Screen widget, tap Pause/Resume and Skip; confirm they
      respond immediately (no multi-second delay) and the widget updates.
- [ ] Tap Restart mid-session; confirm the confirmation alert appears
      (centered, not a bottom sheet) and accepting it resets to a fresh
      Focus session with the cycle dots back to empty.
- [ ] Delete the app and reinstall fresh; confirm the Help sheet appears
      automatically right after the notification primer is dismissed (either
      choice), and that the "?" icon reopens it afterward without
      auto-showing again.
- [ ] Complete 4 Focus sessions in a row (Skip is fine for this); confirm
      the 4th is followed by a Long Break and the cycle dots reset to empty.
