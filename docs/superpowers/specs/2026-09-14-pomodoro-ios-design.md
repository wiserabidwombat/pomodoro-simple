# Pomodoro iOS App — Design Spec

Date: 2026-09-14
Status: Approved by user, pending written-spec review

## Purpose

A simple iOS Pomodoro timer app for the App Store. Its distinguishing
feature is a StandBy-screen widget/Live Activity that shows a live,
interactive countdown (pause/resume/skip) without opening the app.
The app has a fixed black background with a user-selectable text
color, applied consistently across the app, the idle widget, and the
Live Activity.

## Constraints

- Development happens on a Mac (Xcode required for Swift/SwiftUI,
  WidgetKit, and ActivityKit — none of this runs on Windows). This
  session writes the full Xcode project; the user builds, runs, and
  submits it from Xcode.
- Target: iOS 17+ (required for `ActivityKit` Live Activities with
  interactive `LiveActivityIntent` buttons, and for SwiftData).
- User has general programming experience but is new to iOS/Xcode —
  setup steps that must happen inside Xcode (App Group capability,
  signing, notification entitlement) are called out explicitly since
  they cannot be scripted from outside Xcode.

## Non-goals (v1)

- No user-configurable durations (fixed 25/5/15-style classic
  Pomodoro cycle).
- No account system, sync across devices, or backend.
- No Apple Watch app.
- No light/dark mode toggle — background is always black by design;
  only the text/accent color is user-selectable.
- No attempt to override the system-enforced monochrome/vibrant
  rendering of accessory widgets when placed on the *actual* Lock
  Screen (see "Known platform limitation" below) — StandBy and the
  Live Activity are the actual target surfaces for full custom color.

## Architecture

One Xcode project, two targets:

- **`Pomodoro`** (app target) — SwiftUI app, `TabView` with a Timer
  screen and a Stats screen, plus a Settings screen for color choice.
- **`PomodoroWidget`** (widget extension target) — hosts both the
  idle StandBy/Lock Screen widget (`WidgetKit` `TimelineProvider`)
  and the Live Activity UI (`ActivityConfiguration`). Both live in one
  extension bundle, which is how modern WidgetKit projects are
  structured — there is no reason to split them into two extensions.

Both targets share an **App Group** (e.g.
`group.com.<user>.pomodoro`), configured as a capability on both
targets in Xcode's Signing & Capabilities tab. This is a manual,
one-time Xcode step (App Group entitlements cannot be created from
outside Xcode/the Apple Developer portal). The App Group's shared
`UserDefaults` suite is the single source of truth both processes
read and write — there is no other IPC between the app and the
widget extension.

## Components

### 1. Timer engine (app target)

- Tracks: current phase (`.work` / `.shortBreak` / `.longBreak`),
  cycles completed, `endDate` (not a ticking `Timer`/`Date()` diff
  loop — remaining time is always computed as `endDate - Date()`).
  Using an absolute end date rather than a running timer means the
  countdown is correct even after the app is suspended/killed, and it
  is what lets SwiftUI's `Text(timerInterval:)` render a live,
  self-updating countdown in both the app and the widget/Live
  Activity without any manual per-second refresh code.
- Fixed schedule: 25 min work → 5 min short break, repeating; every
  4th break is a 15 min long break. Cycle count resets after a long
  break.
- Every state transition (start / pause / resume / skip) writes a
  small `Codable` `PomodoroState` struct to the shared
  `UserDefaults(suiteName: appGroupID)`.

### 2. Live Activity (widget extension target)

- `PomodoroActivityAttributes`: static attributes (none needed beyond
  a session id) + dynamic `ContentState` (phase, `endDate`, `isPaused`,
  cycle count, chosen accent color). Defined once in a file shared
  (via target membership on both targets) between the app and widget
  extension, since both need the same type.
- Started by the app when the user taps Start, via
  `Activity<PomodoroActivityAttributes>.request(...)`.
- UI: black background, phase label and live countdown
  (`Text(timerInterval:pauseTime:countsDown:)`) in the user's chosen
  accent color, plus Pause/Resume/Skip buttons.
- Buttons are `LiveActivityIntent`s (iOS 17+): they run directly in
  the widget extension process (no app launch required), update the
  shared `PomodoroState` in the App Group `UserDefaults`, and call
  `Activity.update(...)` themselves to refresh the Live Activity's
  content immediately.
- Live Activities are what actually render on the StandBy screen (in
  its large, landscape "banner" layout), the Lock Screen, and the
  Dynamic Island — this is the mechanism that satisfies "interactive
  countdown on StandBy."
- Before starting, the app checks
  `ActivityAuthorizationInfo().areActivitiesEnabled`; if `false` (user
  disabled Live Activities in Settings), it falls back to running the
  timer in-app only, backed by the local notification described
  below, with no crash and no attempt to show anything on StandBy.

### 3. Idle widget (widget extension target)

- A standard `WidgetKit` widget (`accessoryRectangular` /
  `systemSmall` families) shown when no session is currently running.
- Displays the app's icon/name on a black background in the chosen
  accent color, and is a plain deep link (`widgetURL`) into the app's
  Timer screen — tapping it opens the app rather than starting a
  session directly from the widget process. Starting a Live Activity
  reliably from a widget-extension `AppIntent` (as opposed to
  updating an already-running one) has more platform edge cases than
  starting it from the foregrounded app, so the idle widget's only job
  is "get me into the app fast," not "start the timer itself."
- Once a session is running, the idle widget's timeline can show the
  same live state (for placements where a user has it on their Home
  Screen), but the Live Activity is the primary/expected surface for
  an in-progress session.

### 4. Notifications, sound, and haptics (app target)

- On every phase start, the app schedules one local notification
  (`UNUserNotificationCenter`) for that phase's `endDate`, as a backup
  completion signal — this fires even if the app was backgrounded and
  guarantees the user is alerted even in the edge case where the Live
  Activity update path didn't run (e.g., Live Activities disabled).
- When the app is in the foreground at phase end, it also plays a
  sound and triggers a haptic (`UINotificationFeedbackGenerator`)
  directly, rather than relying on the notification banner.
- Notification permission is requested once, on first launch of the
  Timer screen; if denied, the app continues to work with in-app
  sound/haptics only while foregrounded — this is stated to the user
  once and not re-prompted.

### 5. History & stats (app target only)

- `SwiftData` model `CompletedSession` (date, phase type, duration)
  saved each time a work phase completes fully (skipped/abandoned
  phases are not recorded as completed).
- Stats screen: today's completed count, all-time total, simple list
  grouped by day. No charts/graphs in v1 — YAGNI.
- Lives only in the app's local SwiftData store — the widget/Live
  Activity never need history data, so it is not written to the App
  Group.

### 6. Appearance (app target, read by widget extension)

- Background is always black — not a setting, not a toggle.
- Settings screen offers a row of 7–8 preset swatches (white, red,
  orange, yellow, green, cyan, purple — chosen upfront for readable
  contrast against black) for the text/accent color. No full custom
  color picker in v1 (avoids unreadable low-contrast combinations).
- The chosen color is stored in the same App Group `UserDefaults` as
  `PomodoroState`, so the Timer screen, Stats screen, idle widget, and
  Live Activity all read the one value and stay visually consistent.
- **Known platform limitation:** if the idle widget is placed on the
  *actual* Lock Screen (not StandBy) in the small "accessory" widget
  family, iOS forces those into its own monochrome/vibrant rendering
  and ignores any custom background/text color — this is an OS-level
  rule for that specific placement, not something the app can
  override. It does not affect StandBy, the Live Activity, or the main
  app, which are the actual targets for this feature.

## Data flow summary

1. User taps Start in the app → `TimerEngine` sets phase/`endDate` →
   writes `PomodoroState` to App Group `UserDefaults` → schedules
   local notification → starts (or updates) the Live Activity.
2. User taps Pause/Resume/Skip **in the Live Activity** → the
   corresponding `LiveActivityIntent` runs in the widget extension
   process → updates `PomodoroState` in the shared `UserDefaults` →
   calls `Activity.update(...)` directly → re-schedules/cancels the
   local notification to match the new `endDate`.
3. User reopens the app after acting from the Live Activity →
   `TimerEngine` reads the latest `PomodoroState` from the App Group
   `UserDefaults` on `scenePhase` becoming `.active`, so its
   `@Published` state resyncs to whatever happened while it was
   backgrounded.
4. On a work phase's natural completion (not skipped), the app
   records a `CompletedSession` via SwiftData for the Stats screen.

## Error handling

- Live Activities disabled by user → detected via
  `areActivitiesEnabled` before starting one; app falls back to
  in-app timer + notification, no crash, no error dialog (this is a
  normal user choice, not a failure state).
- Notification permission denied → app functions with foreground-only
  sound/haptic; stated once, not re-prompted every launch.
- App Group misconfigured (missed Xcode setup step) → shared
  `UserDefaults` reads return `nil`/defaults; this is a setup-time
  issue caught during manual testing, not something to defensively
  code around at runtime.

## Testing

- **Unit tests** (app target): `TimerEngine` phase transitions, cycle
  counting (4 work phases → long break → reset), and `PomodoroState`
  encode/decode round-trip. Pure Swift, no UI dependency.
- **Manual testing checklist** (widget/Live Activity/StandBy visuals
  cannot be unit tested):
  - Start a session, background the app, confirm Live Activity shows
    on Lock Screen with live countdown and correct color.
  - Simulator: Features menu → StandBy, confirm landscape rendering.
  - Physical device: dock/charge in landscape, confirm StandBy
    appearance matches Simulator.
  - Tap Pause/Resume/Skip from the Lock Screen/StandBy Live Activity
    with the app backgrounded; reopen the app and confirm its UI
    reflects the change.
  - Deny notification permission on a fresh install; confirm the app
    still runs a full session with foreground sound/haptic only.
  - Toggle each of the 7–8 preset colors in Settings; confirm the
    Timer screen, idle widget, and Live Activity all update.

## Open items for implementation plan

- Exact App Group identifier and bundle identifiers (user's Apple
  Developer team/account details — needed once in Xcode, not a design
  decision).
- App icon artwork — a simple placeholder icon will be generated;
  user may swap in real artwork before submission.
