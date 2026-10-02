# Manual testing checklist

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
- [ ] Settings → Holiday Theme → Halloween: the Timer, Stats and Settings
      screens get a purple tint at the top and orange accents; bats, ghosts
      and pumpkins drift up behind the Timer. The Live Activity and widgets
      turn orange within a few seconds. Finish a Focus session with the app
      open: a burst of emoji plays. Try Thanksgiving (falling leaves) and
      Christmas (falling snow). Back to Off: your own accent color returns.
- [ ] With Reduce Motion on (Settings → Accessibility → Motion), the
      particles hold still and no burst plays. Same for the drift in Low
      Power Mode.
- [ ] Holiday Theme → Automatic in October shows Halloween.
- [ ] Let a work phase's countdown run out with the app foregrounded; confirm
      it auto-advances to a short break and the Stats screen's "Today" count
      increments by one.
- [ ] Add the small round (circular) widget to the Lock Screen and start a
      session: the ring drains in real time with the countdown in the middle,
      with the app closed. Pause: the ring freezes with a pause glyph.
      Pause/resume a few times; the ring still matches the countdown. When
      the phase ends, the ring empties and shows a checkmark.
- [ ] Add the idle widget to the Home Screen and to the Lock Screen; confirm
      tapping either opens the app.
- [ ] From the Home Screen widget, tap Pause/Resume and Skip; confirm they
      respond immediately (no multi-second delay) and the widget updates.
- [ ] With no session running, tap Start on the small and medium Home Screen
      widgets (app closed); confirm a session starts with the active profile,
      the Live Activity appears on the Lock Screen, and opening the app shows
      it running. Tapping Start again right away must not restart it.
- [ ] Tap Skip during Focus: a prompt asks first. Before the halfway mark it
      offers only "Skip Without Counting"; past halfway it also offers
      "Finish & Count It", which moves to the break, fills a cycle dot, and
      adds the session to Stats with the minutes actually focused. Skip
      during a break still skips immediately.
- [ ] Tap Restart mid-session; confirm the confirmation alert appears
      (centered, not a bottom sheet) and accepting it resets to a fresh
      Focus session with the cycle dots back to empty.
- [ ] Delete the app and reinstall fresh; confirm the Help sheet appears
      automatically right after the notification primer is dismissed (either
      choice), and that the "?" icon reopens it afterward without
      auto-showing again.
- [ ] Complete 4 Focus sessions in a row (Skip is fine for this); confirm
      the 4th is followed by a Long Break and the cycle dots reset to empty.
- [ ] On a fresh install with no sessions yet, open the Stats tab and confirm
      it loads (zeros, an empty 7-day chart, and the "Completed Focus sessions
      will show up here" message) without crashing.
- [ ] With the app open, let a *break* run out; confirm it advances to Focus
      once, the chime/haptic plays once (no system notification sound on top),
      and the new Focus countdown actually counts down.
- [ ] Let a Focus session run out with the phone locked, then tap Continue on
      the Lock Screen Live Activity (or dismiss the notification); open the
      app and confirm Stats and the medium widget's "Today" count include it.
- [ ] Start a session, force-quit the app, reopen it mid-phase; confirm the
      countdown is right and the phase still advances on its own at zero.
- [ ] With the Home Screen widget visible, let a phase run out; confirm it
      switches to "Time's up" with a Continue button, and that Continue
      advances exactly one phase.
- [ ] Mid-session, change the accent color (preset and custom picker);
      confirm the Live Activity and widget pick it up within a second or two.
- [ ] Turn Settings → Play Sound off mid-phase, lock the phone, and confirm
      the phase-end notification arrives silently.
- [ ] Updating from a build without profiles: confirm Settings → Timer
      Profiles shows "Classic" with the durations you had set before, plus
      "Deep Work", and that existing Stats history appears under Classic.
- [ ] Add a profile with 2 sessions per cycle; select it on the Timer screen;
      confirm 2 cycle dots and a Long Break after the 2nd Focus session.
- [ ] Start a session and confirm the profile menu can't be changed until
      it's stopped, and that the profile you're using can't be deleted.
- [ ] With 2+ profiles, confirm the Live Activity, widget, and phase-end
      notification read "<Profile> · Focus".
- [ ] Finish sessions under two profiles; confirm Stats → All Profiles shows
      the combined totals plus a By Profile breakdown, and tapping a profile
      (or picking it in "Showing") filters the whole screen to it.
- [ ] Settings → Daily Goal: set 3. The Timer screen shows "0 of 3 today"
      with a bar that fills as sessions finish (from any profile), then
      "Daily goal reached". The medium widget shows "1/3" and "Goal met" once
      reached. Stats (All Profiles) gets a Daily Goal section and a dashed goal
      line on the 7-day chart; picking one profile hides them. Set it back to
      0 and all of it disappears.
- [ ] Stats → Export History as CSV: share to Files or Mail, open it in
      Numbers/Excel; confirm one row per session (date, time, profile,
      minutes), oldest first, including sessions from a deleted profile. The
      button is hidden when there's no history yet.
- [ ] Delete a profile that has history; confirm its sessions still count in
      the overall stats and it's still selectable under "Showing".
- [ ] Turn on Settings → Keep Screen Awake, start a session, and leave the
      phone on the Timer screen past its Auto-Lock time; confirm it stays on.
      Then confirm it does lock normally after switching to another tab, when no
      session is running, or with the setting off.
- [ ] Siri: "Start Deep Work with Simple Timer" starts that profile (Siri
      says "Starting Deep Work."), and the Timer screen shows Deep Work when
      opened. Add or rename a profile, then confirm Siri recognizes the new
      name. Asking while a session is running says it's already running and
      changes nothing.
- [ ] Action Button (iPhone 15 Pro and later): Settings → Action Button →
      Shortcut → Simple: StandBy Timer → Start Timer Profile, pick a profile;
      pressing the button starts it with the Live Activity, app closed.
- [ ] VoiceOver pass (Settings → Accessibility → VoiceOver, or triple-click
      the side button if set up): swipe through Timer, Stats, and Settings.
      Every control should say what it is ("How it works", "Restart session",
      "Cycle progress, 2 of 4 Focus sessions done", color names), the paused
      time should read as "Paused, 12 minutes, 34 seconds remaining", and
      Stats rows should read as one item each ("Today, 3 sessions").
- [ ] Largest text size (Settings → Accessibility → Display & Text Size →
      Larger Text, max): Timer, Stats, Settings, and the profile editor stay
      usable, and "Resume" isn't cut off.
- [ ] Pick a very dark custom color; confirm Settings shows the
      hard-to-read warning.
- [ ] Pick a custom color with the color picker in Settings; confirm the Timer
      screen, idle widget, and Live Activity all use it.
- [ ] Edit a profile's Focus, Short Break, and Long Break durations in
      Settings → Timer Profiles; confirm the next session of each type uses
      the new duration, and the idle widget and Live Activity show the
      correct countdown.
- [ ] Let a phase end with the phone locked, then clear the phase-end
      notification (once on the phone, once on a paired Apple Watch). Wait a
      minute, open the app: no TestFlight crash prompt, and the timer has
      moved on to the next phase.
- [ ] Lock Screen Skip during Focus: past halfway, Skip on the Live Activity
      (or Home Screen widget) moves to the break, fills a cycle dot, and the
      session shows in Stats with the minutes focused. Before halfway it
      skips without counting. Turn off Settings → Lock Screen Skip Counts
      Focus and confirm Skip past halfway no longer counts.
- [ ] iPad layout (Simulator or device), full screen: a tab bar (floating at
      the top on iPadOS 18), not a sidebar. Landscape: the ring and big
      buttons on the left, Today / Up next / This week / Profile cards on
      the right. Portrait: the ring on top, the cards in a 2×2 grid below.
      The ring drains as the phase runs and freezes when paused; idle, it's
      full and shows the Focus length. Stats and Settings are centered and
      capped in width. Narrow Split View / Slide Over shows the iPhone layout.
      Tapping the widget or notification still lands on Timer.
- [ ] iPad cards: Today shows the count (and "of N" with a goal) and minutes
      focused; Up next names the next two phases with lengths (Long Break
      after the cycle's last Focus); This week matches Stats' chart; the
      Profile card switches profiles only while idle.
- [ ] Desk Mode (expand button at top right, or ⌘D): only the ring,
      countdown, and time of day, with no tab bar or status bar; the screen
      stays on. Tap anywhere or press Escape to leave. Rotating keeps it
      centered; going to narrow Split View leaves it.
- [ ] iPad with a keyboard: Space starts/pauses/resumes, S skips (Focus
      still asks first), ⌘R restarts, ⌘D opens Desk Mode and Escape leaves
      it, ⌘1/⌘2/⌘3 switch screens. Holding ⌘ lists the shortcuts.
- [ ] iPad wording: Help shows "Widgets & notifications" and "Keyboard"
      plus Desk Mode (no Dynamic Island, StandBy, or Action Button); the
      primer and Keep Screen Awake say "iPad"; Settings shows "Widget Skip
      Counts Focus".
- [ ] iPad with a holiday theme: the tint reaches both edges on every tab,
      and particles drift across the whole Timer screen.
- [ ] iPad: starting a session doesn't error or hang without Live
      Activities; widgets, notifications, Siri, and Stats all work.
- [ ] Large widget (iPhone or iPad) and Extra Large (iPad): the countdown
      with Pause/Resume and Skip (or Start when idle), cycle dots, "N of
      goal today", and 7 bars for the week with day letters; days that met
      the goal are brighter. Finish a session from the Lock Screen: today's
      bar and count go up without opening the app.

