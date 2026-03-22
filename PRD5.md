# Run Tracker — Product Requirements Document v5

**Version:** 5.0
**Last updated:** 2026-03-11
**Builds on:** PRD v4 (Phases 14–20 complete)
**Platform:** iOS 17+, iPhone only
**Tech stack:** Swift, SwiftUI, MapKit, Core Location, Core Motion, SwiftData, AVSpeechSynthesizer, WeatherKit

---

## Table of Contents

1. [Overview](#1-overview)
2. [Landing Page Map Centering](#2-landing-page-map-centering)
3. [Pre-Run Countdown](#3-pre-run-countdown)
4. [Cool Down Phase](#4-cool-down-phase)
5. [Split Table Redesign](#5-split-table-redesign)
6. [Elevation Chart Scaling Fix](#6-elevation-chart-scaling-fix)
7. [Data Model Changes](#7-data-model-changes)

---

## 1. Overview

PRD v5 focuses on run UX polish and data clarity:

1. **Map centering** — On the idle screen, position the map so the user's location dot sits at the visual midpoint between the Start button and the top of the screen.
2. **Pre-run countdown** — A 10-second animated countdown after tapping Start gives the user time to pocket the phone; tapping the countdown skips it.
3. **Cool down phase** — A toggle button lets users mark segments of a run as cool-down, splitting stats between "running" and "cool down" for cleaner analysis.
4. **Splits table redesign** — Improve the visual design of the splits table in `RunSummaryView`.
5. **Elevation chart scaling** — The elevation chart's Y axis should use the full available vertical range whenever there is measurable elevation change.

---

## 2. Landing Page Map Centering

### Problem

On the idle (pre-run) screen, the map is centered on the user's raw coordinate, which places the user dot near the vertical center of the full screen. The Start button occupies the bottom portion of the screen. The effective "visible map area" above the Start button is only about half the screen, making the dot feel off-center in the visible region.

### Desired Behavior

The user's location dot should appear at the **vertical midpoint of the visible map area** — i.e., halfway between the top edge of the screen and the top edge of the Start button panel.

### Implementation

The idle screen layout has a `Map` view that fills the screen with the bottom controls overlaid. Determine the pixel height of the overlay panel (Start button + last run card). The visible map height is `screenHeight - overlayHeight`. The desired camera target is the user's true coordinate shifted south by `overlayHeight / 2` in screen-space pixels, converted to degrees of latitude.

**Approach:**

1. Measure the overlay panel height using `GeometryReader` or a fixed known constant (e.g., 220 pt).
2. At the current map zoom level (`latitudeDelta ≈ 0.005`), compute how many degrees of latitude correspond to half the overlay height:
   - At zoom `latitudeDelta = 0.005`, the full screen height ≈ 0.005° of latitude.
   - Degrees per point ≈ `latitudeDelta / screenHeight`.
   - Offset (degrees) = `(overlayHeight / 2) * degreesPerPoint`.
3. Set the map camera center to `CLLocationCoordinate2D(latitude: userLat - offset, longitude: userLon)` so the dot appears visually centered in the upper portion.
4. Recalculate when the user's location updates or the layout changes.
5. Do not apply this offset during an active or paused run — only on the idle screen.

### Acceptance Criteria

- [ ] On the idle screen, the user's location dot appears halfway between the top of the screen and the top of the Start button / bottom panel.
- [ ] The offset updates when the user location changes.
- [ ] The layout works correctly on all iPhone sizes (small: iPhone SE, standard: iPhone 16, large: iPhone 16 Pro Max).
- [ ] No visual jump or flash when location first becomes available.
- [ ] Active run map is unaffected.

---

## 3. Pre-Run Countdown

### Problem

Tapping Start immediately begins the run. Users who want to pocket their phone before starting have no grace period. A countdown gives time to secure the phone and mentally prepare.

### Desired Behavior

After tapping Start (or selecting a route and confirming), a **10-second countdown** plays before the run timer begins. The countdown is displayed large and centered on screen. Tapping anywhere on the countdown dismisses it and starts the run immediately.

### Run State Addition

Add a new `RunState` case: `.countdown`. The state machine flow becomes:

```
.idle → .countdown → .active → .paused ↔ .active → .stopped
```

During `.countdown`:
- GPS tracking starts (to get a valid initial fix and first coordinate)
- The run timer does NOT start
- Distance accumulation does NOT start
- The map remains visible in the background (same layout as active run)

### UI

- Display a large number (10 → 1) in a bold, monospaced font centered in the map area.
- Animate each digit with a subtle scale pulse (scale from 1.2 → 1.0 over 0.8s, then hold until next tick).
- Show a small "Tap to skip" hint below the number.
- Background: the live map, same as the active run view (map top, controls bottom).
- The bottom control area shows no buttons during countdown (or a single "Cancel" button to abort).

### Behavior

- A 1-second `Timer` decrements the counter from 10 to 0.
- When counter reaches 0, call `startRunNow()` — same as `startRun()` but skipping the countdown.
- Tapping the countdown area (number or hint) calls `startRunNow()` immediately.
- If the user taps "Cancel" during the countdown, return to `.idle`.
- Audio: optionally speak "3, 2, 1, Go!" for the last 3 seconds if audio cues are enabled (a light haptic at each second is sufficient; voice is optional and off by default).
- The countdown state is NOT preserved across app restarts. If the app is killed during countdown, return to `.idle`.

### Acceptance Criteria

- [ ] Tapping Start begins a 10-second countdown before the run timer starts.
- [ ] The countdown shows a large animated digit counting down from 10.
- [ ] Tapping the countdown skips to the run immediately.
- [ ] GPS tracking is active during the countdown (the run gets a good initial fix).
- [ ] Distance and time do not accumulate during the countdown.
- [ ] A "Cancel" option exits the countdown and returns to idle.
- [ ] The countdown works correctly after route selection (the countdown is the last step before the run starts).
- [ ] Light haptic feedback fires on each countdown tick.

---

## 4. Cool Down Phase

### Problem

Runners often finish a run with a cool-down walk. Currently all distance, time, and pace metrics lump the cool-down in with the run, inflating average pace. Users want to track cool-down separately so their running stats remain accurate.

### Concept

A **cool-down toggle** button is available during an active or paused run. When cool-down mode is on, the current segment is marked as cool-down. Each `Split` records whether it was generated during cool-down. Stats can be filtered to show "total" or "running only" (excluding cool-down).

Cool-down is a **toggle**, not a one-way transition. A user can toggle it on mid-run to walk, then toggle it off to resume running — this mirrors real-world interval training and run/walk approaches.

### UI — Active Run Controls

Add a **Cool Down** button next to the existing Pause and Stop buttons on the active run control bar.

- **Icon:** `figure.walk` (walking figure SF Symbol)
- **Label:** "Cool Down" when off, "Running" when on (indicating tapping will switch back)
- **Color:** Gray/secondary when off (cool-down inactive), blue when on (cool-down active)
- **Placement:** Between the pause button and the stop button in the bottom control strip.
- The button is visible in both `.active` and `.paused` states.
- When `.paused`, toggling cool-down mode is allowed but takes effect when the run resumes.

### Data Model — Split Changes

Add `isCoolDown: Bool` to the `Split` model (default `false`).

When a split boundary is crossed, the split is tagged with the value of `isCoolDown` at the moment the boundary was reached. A split that spans a mode change (e.g., the user toggled cool-down mid-split) is tagged with whichever mode was active for the **majority** of that split's distance. Simple implementation: tag with the current mode when the boundary is crossed.

### Data Model — Run Changes

Add to the `Run` model:

```swift
var hasCoolDown: Bool          // true if cool-down was used at any point during the run
var coolDownDistanceMeters: Double   // total distance accumulated in cool-down segments
var coolDownDurationSeconds: Double  // total time spent in cool-down mode
```

### Stats Display During Active Run

Add a setting: **"Show: Total / Running Only"** in Settings (or as a toggle on the active run screen). This controls what the distance and elapsed time stats show:

- **Total** — all accumulated distance and time (current behavior)
- **Running Only** — distance and time excluding cool-down segments

When "Running Only" is selected:
- The distance stat shows running-only distance
- The elapsed time stat shows running-only time
- Pace is computed from running-only distance / running-only time
- A small secondary label beneath the main stats shows the total in parentheses, e.g., "(3.2 mi total)"

The setting defaults to **Total** to preserve existing behavior.

### Run Summary

If `hasCoolDown == true` on a run, the summary shows two sets of stats:

1. **Running** section: distance, time, average pace, elevation — excluding cool-down splits
2. **Total** section: full run distance, total time — including cool-down

If `hasCoolDown == false`, show only the existing single stats section (no change).

The split table in the summary labels each split row. Cool-down splits show a small `figure.walk` icon and a "Cool Down" badge. Running splits show no extra badge (they are the default).

### Audio Cues

When cool-down mode is active, audio cues continue to fire normally. The spoken text prepends "Cool down — " to the cue:
> "Cool down — Five minutes. Zero point four miles."

When transitioning to cool-down mode, speak: "Cool down started."
When transitioning back to running mode, speak: "Running resumed."
These transition cues fire only if audio cues are enabled globally.

### Acceptance Criteria

- [ ] A Cool Down toggle button appears on the active run control bar.
- [ ] Toggling cool-down on changes the button appearance and begins marking the segment.
- [ ] Toggling cool-down off resumes normal run tracking.
- [ ] Each `Split` is tagged with `isCoolDown`.
- [ ] `Run.hasCoolDown`, `coolDownDistanceMeters`, and `coolDownDurationSeconds` are populated on `stopRun()`.
- [ ] The active run stat display has a "Total / Running Only" toggle that correctly filters distance and time.
- [ ] When "Running Only" is selected, a secondary label shows the total in parentheses.
- [ ] `RunSummaryView` shows separate Running and Total stats sections only when `hasCoolDown == true`.
- [ ] Cool-down splits are visually distinguished in the split table (walk icon + badge).
- [ ] Audio cues work correctly in cool-down mode with appropriate prefixes.
- [ ] Cool-down state persists correctly across pause/resume cycles.

---

## 5. Split Table Redesign

### Problem

The current `SplitTableView` is a plain list with small text and no visual hierarchy. Fastest/slowest highlighting uses text color only. It is hard to scan at a glance.

### Redesign Goals

- Each split row should be a distinct, card-like cell with clear visual separation.
- The split number/label should be large and prominent.
- Pace should be the hero stat (largest text in the row).
- Secondary stats (distance, elevation, cadence) should be smaller and in a supporting role.
- Fastest split: green left accent bar (3 pt vertical bar on leading edge of the card).
- Slowest split: red left accent bar.
- Cool-down splits (from §4): secondary background color (e.g., system fill) with a walk icon.
- Partial (final) split: italic pace + "(partial)" label.
- Compact enough that 5–8 splits fit on screen without scrolling (target: ~72 pt row height).

### Layout per Row

```
┌─ [accent bar] ──────────────────────────────────────────┐
│  Mi 1          [figure.walk icon if cool-down]           │
│  7:42 /mi          ↑ 24 ft   ↓ 8 ft   ♦ 168 spm        │
│  1.00 mi · 7:42                                          │
└──────────────────────────────────────────────────────────┘
```

- Row height: ~72 pt
- Left accent bar: 3 pt wide, full row height, color: green (fastest), red (slowest), clear (other)
- Split label ("Mi 1", "Km 1", "¼ Mi 2", etc.) — `.headline` weight
- Pace — large, `.title2` weight, monospaced
- Secondary row: elevation gain/loss with up/down arrows, cadence with diamond icon, all `.caption`
- Distance · duration — `.caption2` or `.footnote`, trailing aligned

### Acceptance Criteria

- [ ] Split rows use the card-style layout described above.
- [ ] Fastest split has a green left accent bar; slowest has red.
- [ ] Cool-down splits have a secondary background and walk icon.
- [ ] Partial splits are italicized with a "(partial)" label.
- [ ] The table is readable and scannable on all iPhone sizes.
- [ ] The split label reflects the configured split distance (¼ mi, ½ mi, mi, km, etc.).

---

## 6. Elevation Chart Scaling Fix

### Problem

The `ElevationProfileChart` Y axis is not auto-scaled to the run's actual elevation range. When there is only a small elevation change (e.g., 10–20 ft over a flat run), the chart Y axis starts at 0 (or some large value) and the elevation line appears nearly flat — the change is invisible.

### Fix

Scale the Y axis to the **actual min/max elevation of the run** with a small padding:

```swift
let minEle = routePoints.map(\.altitudeMeters).min() ?? 0
let maxEle = routePoints.map(\.altitudeMeters).max() ?? 0
let padding = max((maxEle - minEle) * 0.15, 1.0)  // at least 1m padding
let yMin = minEle - padding
let yMax = maxEle + padding
```

Apply via `.chartYScale(domain: yMin...yMax)` on the Swift Charts view.

If `maxEle == minEle` (perfectly flat run), display a flat line with the axis range set to `[elevation - 5, elevation + 5]` (in display units), so the chart is not a degenerate zero-height range.

Convert all values to display units (ft or m) before computing the range — the chart should show the same units as the rest of the app.

### Acceptance Criteria

- [ ] A run with 20 ft of elevation change shows a clearly visible profile — the line uses the full chart height.
- [ ] A perfectly flat run shows a flat line (no crash, no degenerate range).
- [ ] A run with 500+ ft of change continues to render correctly.
- [ ] Y axis labels show the actual elevation values in the user's unit system (ft or m).
- [ ] The fix applies to both `RunSummaryView` and any other view using `ElevationProfileChart`.

---

## 7. Data Model Changes

### Split Model — New Property

```swift
var isCoolDown: Bool   // default false
```

### Run Model — New Properties

```swift
var hasCoolDown: Bool               // true if cool-down was toggled at any point
var coolDownDistanceMeters: Double   // total distance in cool-down mode
var coolDownDurationSeconds: Double  // total duration in cool-down mode
```

### RunState Enum — New Case

```swift
case countdown   // between .idle and .active; GPS on, timer/distance off
```

### Settings — New Key

```swift
@AppStorage("activeRunStatDisplay")  // "total" | "runningOnly", default "total"
```

### No migration required for existing runs

- `Split.isCoolDown` defaults to `false` — existing splits are treated as running splits.
- `Run.hasCoolDown` defaults to `false` — existing runs show only the existing single-stats layout.
- `Run.coolDownDistanceMeters` and `coolDownDurationSeconds` default to `0`.

### RouteCheckpoint Model — New

```swift
@Model class RouteCheckpoint {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var label: String          // "Checkpoint 1", "Checkpoint 2", …
    var order: Int             // 0-based insertion index within the route
    var namedRoute: NamedRoute?
}
```

### RunCheckpointResult Model — New

```swift
@Model class RunCheckpointResult {
    var id: UUID
    var checkpoint: RouteCheckpoint?
    var elapsedSeconds: Double       // time from run start when checkpoint was reached
    var cumulativeDistanceMeters: Double
    var run: Run?
}
```

### NamedRoute — New Relationship

```swift
@Relationship(deleteRule: .cascade) var checkpoints: [RouteCheckpoint] = []
```

### Run — New Relationship

```swift
@Relationship(deleteRule: .cascade) var checkpointResults: [RunCheckpointResult] = []
```

---

## 8. Custom Checkpoint Pins

### Problem

The coach split comparison works against fixed distance boundaries. Runners often care about specific landmarks — top of a climb, end of a street, a turn — that don't align with any split boundary. There is no way to measure or compare time at those landmarks across runs.

### Concept

**Checkpoint pins** are user-dropped location markers placed during a named-route run. Tapping a button during the run saves a `RouteCheckpoint` to the `NamedRoute` at the runner's current GPS coordinate. On subsequent runs of the same route, the engine detects when the runner passes within proximity of each checkpoint and records the elapsed time as a `RunCheckpointResult`. The active-run HUD shows the time delta versus the benchmark run at each checkpoint, exactly like the split coach but for user-defined landmarks.

Checkpoints are a **persistent** part of the route, not the run. Once dropped, they apply to all future runs of that route.

### Dropping a Checkpoint

A **Checkpoint** button (`mappin.and.ellipse` SF Symbol) appears in the map overlay during active named-route runs (below the zoom controls in the top-right corner). It is hidden for free runs.

- Tapping saves a `RouteCheckpoint` to the `NamedRoute` at the current `CLLocationCoordinate2D`, records the current `elapsedSeconds` and `totalDistanceMeters` as a `RunCheckpointResult` on the current run, and auto-labels it "Checkpoint N" (where N is `checkpoints.count + 1`).
- A brief `CheckpointSavedToastView` slides in: "Checkpoint N saved."
- Checkpoints can be dropped during `.active` or `.paused` run states.
- Practical UI cap: 20 checkpoints per route (show a disabled button with "Max reached" if exceeded).

### Checkpoint Detection During a Run

When `ActiveRunVM` starts a named-route run, it loads the route's `checkpoints` array sorted by `order`. It maintains a `nextCheckpointIndex: Int = 0` cursor. On each GPS location update, compute the distance from `currentLocation` to `checkpoints[nextCheckpointIndex].coordinate`. If within **20 metres**, record a `RunCheckpointResult` (current `elapsedSeconds`, `totalDistanceMeters`), advance `nextCheckpointIndex`, and publish `latestCheckpointResult` to trigger the toast.

The reference for delta comparison is the benchmark run (`NamedRoute.benchmarkRunID`). Load that run's `checkpointResults` at init. When a checkpoint is reached, look up the benchmark's result for the same `RouteCheckpoint` by matching `checkpoint.id`. If found, compute `delta = currentElapsed - benchmarkElapsed` and include it in the toast. If the benchmark run has no result for this checkpoint (checkpoints added after the benchmark was set), show elapsed time only with no delta.

### Active Run UI

- **Drop button:** `mappin.and.ellipse`, top-right map overlay, below zoom controls. Blue tint. Only shown when `runState == .active || .paused` and a named route is selected.
- **CheckpointToastView:** slide-down banner (same style as `SplitToastView`). Shows: checkpoint label ("Checkpoint 1"), current elapsed time at the checkpoint, and delta badge ("+0:12" red if behind benchmark, "−0:05" green if ahead). Auto-dismiss after 4 seconds. Overlaps the split toast if both appear simultaneously — stack vertically.
- **Map annotations:** Checkpoint pins rendered as `Annotation` views using `mappin.fill` in orange, with a small numeric label (the checkpoint order + 1). Visible on both the live map (all dropped checkpoints) and the route detail map.

### Run Summary

If `run.checkpointResults` is non-empty, show a **"Checkpoints"** section in `RunSummaryView` below the splits table. Each row shows: checkpoint label, elapsed time at checkpoint, and delta vs benchmark (if available). Use the same card-style row as the redesigned splits table.

### Route Detail View

Checkpoint pins are shown on the route map in `RouteDetailView` as orange `mappin.fill` annotations alongside split markers. Long-pressing a checkpoint pin shows a context menu with a "Delete Checkpoint" option (confirmation alert: "Remove this checkpoint from all future runs?"). Deleting a `RouteCheckpoint` via SwiftData cascade-deletes all associated `RunCheckpointResult` rows.

### Acceptance Criteria

- [ ] A "Checkpoint" button appears on the map overlay during active named-route runs only.
- [ ] Tapping saves a `RouteCheckpoint` to the `NamedRoute` and a `RunCheckpointResult` to the current run. A toast confirms.
- [ ] On a subsequent run, passing within 20 m of a checkpoint triggers a toast with elapsed time and delta vs benchmark.
- [ ] Delta is green when ahead, red when behind. No delta is shown if the benchmark has no result for that checkpoint.
- [ ] Checkpoint pins are visible (orange) on the live map during the run.
- [ ] Checkpoint pins are visible on the route detail map with a long-press delete option.
- [ ] The run summary shows a Checkpoints section when `checkpointResults` is non-empty.
- [ ] Deleting a checkpoint from `RouteDetailView` removes it and all its results.
- [ ] The button is disabled (not hidden) after 20 checkpoints with a "Max reached" tooltip.
- [ ] Free runs show no checkpoint button.

---

*End of PRD v5.*
