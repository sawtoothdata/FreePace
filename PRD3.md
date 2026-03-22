# Run Tracker — Product Requirements Document v3

**Version:** 3.0
**Last updated:** 2026-03-08
**Builds on:** PRD v2 (Phases 7–9 complete)
**Platform:** iOS 17+, iPhone only
**Tech stack:** Swift, SwiftUI, MapKit, Core Location, Core Motion, SwiftData, AVSpeechSynthesizer

---

## Table of Contents

1. [Overview](#1-overview)
2. [App Icon Redesign](#2-app-icon-redesign)
3. [Split Audio Cues — Pace per Unit](#3-split-audio-cues--pace-per-unit)
4. [Route Selection at Run Start](#4-route-selection-at-run-start)
5. [Named Route Detail View Overhaul](#5-named-route-detail-view-overhaul)
6. [Coach Mode for Named Routes](#6-coach-mode-for-named-routes)
7. [Run Summary View — Restyle Action Buttons](#7-run-summary-view--restyle-action-buttons)

---

## 1. Overview

PRD v3 addresses usability feedback and adds coaching features for named routes. The five changes are:

1. **App icon redesign** — Replace the current icon with a cleaner, simpler design.
2. **Split pace units** — Audio split announcements should use the correct unit (min/km or min/mi).
3. **Route picker at run start** — Prompt the user to select a named route before starting.
4. **Route detail view overhaul** — Show the route as a map path with split markers and timing info.
5. **Coach mode** — Optional live audio comparison against previous runs on a named route.

---

## 2. App Icon Redesign

### Problem

The current app icon looks amateurish. It needs to be simple, clean, and immediately recognizable.

### Design Direction

- **Color scheme:** Green (#30D158) on black background.
- **Style:** Minimal and geometric. No detailed silhouettes or clip-art.
- **Concept options** (pick one):
  - A single bold forward-pointing chevron or arrow suggesting movement/speed
  - An abstract running shoe footprint
  - A simple GPS route line forming an abstract shape
- **No text** in the icon.
- Clean edges, no gradients or shadows — flat design.
- The icon should read clearly at 29×29 pt (smallest size) and 1024×1024 (App Store).

### Acceptance Criteria

- [ ] New icon replaces the existing one in `Assets.xcassets/AppIcon.appiconset`.
- [ ] Icon is provided at 1024×1024 and all required device sizes.
- [ ] Icon is simple enough to be recognizable at small sizes.
- [ ] Uses green and black color scheme.

---

## 3. Split Audio Cues — Pace per Unit

### Problem

Split audio cues currently announce split time but say "per mile" or "per kilometer" for pace. The pace value itself should reflect the user's chosen unit system — minutes per mile for imperial, minutes per km for metric.

### Current Behavior

The `AudioCueService.formatPaceSpeech` method already converts pace using `unit.metersPerDistanceUnit` and appends "per mile" or "per kilometer". However, the split announcement says "Mile 1" or "Kilometer 1" but does not announce the split's pace in the correct per-unit format relative to the split distance setting.

### Change

When splits are configured as half-mile or quarter-mile (or metric equivalents), the audio cue should still announce pace normalized to **per mile** or **per km** (not per quarter-mile). The split label should reflect the actual split distance:

- Quarter: "Quarter mile 1" / "Quarter K 1"
- Half: "Half mile 1" / "Half K 1"
- Full: "Mile 1" / "Kilometer 1"

### Acceptance Criteria

- [ ] Split cues announce the correct split label based on `SplitDistance` setting (e.g., "Half mile 3").
- [ ] Pace is always announced as minutes per mile (imperial) or minutes per km (metric), regardless of split distance.
- [ ] Time-based cues continue to announce pace per mile / per km correctly.

### Technical Notes

- Update `AudioCueService.handleSplit()` to use the current `SplitDistance` setting for the label.
- The pace calculation (`split.durationSeconds / split.distanceMeters * unit.metersPerDistanceUnit`) already normalizes to per-mile/per-km — just verify this is correct.

---

## 4. Route Selection at Run Start

### Problem

Currently, a run must be completed before it can be assigned to a named route (via `RouteAssignmentSheet` in `RunSummaryView`). The user wants to select a route *before* starting so the route overlay, benchmark data, and coach mode are available during the run.

### Change

When the user taps "Start" on the idle screen:
1. If named routes exist, show a route selection sheet with options:
   - **"Free run"** — start without a route (current behavior)
   - **List of named routes** — select one to run
2. If no named routes exist, start immediately (current behavior).
3. When a route is selected, call `ActiveRunVM.setNamedRoute()` before starting the run.
4. The selected route's overlay and benchmark data are visible from the first step.

### UI/UX Description

- The sheet appears as a half-sheet (`.presentationDetents([.medium])`).
- Top option: "Free Run" with a running figure icon, styled as a prominent button.
- Below: "Your Routes" section listing named routes with name and run count.
- Tapping a route or "Free Run" dismisses the sheet and starts the run.
- A "Cancel" button at the top returns to the idle screen without starting.

### Acceptance Criteria

- [ ] Tapping Start shows a route selection sheet when named routes exist.
- [ ] "Free Run" starts a run with no route (existing behavior).
- [ ] Selecting a named route loads its overlay and benchmark data before the run starts.
- [ ] If no named routes exist, tapping Start begins the run immediately.
- [ ] The selected route name is visible somewhere on the active run screen.
- [ ] After the run, the run is automatically assigned to the selected route (no need for post-run assignment).

### Technical Notes

- Add a `@State private var showRouteSelection = false` and `@State private var selectedRoute: NamedRoute?` to `ActiveRunView`.
- Query named routes from SwiftData in the sheet.
- On route selection: set `viewModel.setNamedRoute(route)`, then `viewModel.startRun()`.
- On "Free Run": just `viewModel.startRun()`.
- When a run completes with a pre-selected route, auto-assign it in `stopRun()` or when saving.
- Add `selectedNamedRoute` property to `ActiveRunVM` so the run can be auto-assigned on completion.

---

## 5. Named Route Detail View Overhaul

### Problem

The current `RouteDetailView` shows statistics and a pace trend chart but does not show the actual route on a map. The user wants to see the route path with split locations and timing information.

### Change

Redesign `RouteDetailView` to be map-centric:

1. **Map with route path** — Show the route's GPS trail on a map, fitted to the route bounds. The path should look like a clear trail overlaid on the map.
2. **Split markers on map** — Show markers at each split boundary along the route. Each marker indicates the distance (e.g., "Mile 1", "Mile 2") and optionally the benchmark time at that point.
3. **Timing info** — Show timing data associated with the route:
   - Best time, average time, last run time in a header section.
   - Per-split timing can be shown as annotations on the map or in a companion table below.
4. **Pace coloring** — Optionally color-code the route path by pace (green = fast, red = slow) based on the benchmark run's split data.

### UI/UX Description

- **Top section:** Route name (editable), run count, best/avg/last time.
- **Map section:** Takes up ~60% of the screen. Shows the route as a solid polyline (3-4 pt, green) on the map. Split markers are small pins with distance labels. The map is fitted to show the full route with padding.
- **Below map:** Split table showing each split's benchmark time and pace. Fastest split highlighted green, slowest red (existing `SplitTableView` behavior).
- **Bottom:** Pace trend chart (existing), list of runs on this route.
- **Actions:** Rename, delete route (existing).

### Acceptance Criteria

- [ ] RouteDetailView shows a map with the route path drawn as a polyline.
- [ ] Split markers appear at each split boundary on the map with distance labels.
- [ ] Best time, average time, and last run time are displayed.
- [ ] The map fits the full route with appropriate padding.
- [ ] Existing features (rename, delete, pace trend chart, run list) are preserved.
- [ ] If no benchmark run exists (no runs on route yet — shouldn't happen since routes are created from runs), show the most recent run's path.

### Technical Notes

- Use the benchmark run's (or best run's) `routePoints` to draw the polyline.
- Compute split boundary coordinates from the route points (find the point closest to each split distance).
- Use `Map` with `MapPolyline` and `Annotation` views.
- Fit the map to the route using `.mapCameraPosition` with a computed region from the route's bounding box.

---

## 6. Coach Mode for Named Routes

### Problem

When running a named route, the user wants optional live audio coaching that compares their current performance to their previous runs.

### Change

Add a "Coach Mode" toggle that can be:
- Enabled when selecting a route at run start (checkbox/toggle on the route selection sheet).
- Toggled on/off during the run via a button on the active run screen.

When coach mode is active, audio cues at each split include comparison data:

### Coach Mode Audio Cues

At each split boundary, in addition to the normal split announcement, coach mode adds:

- **vs. Last Run:** "Twelve seconds ahead of your last run" or "Eight seconds behind your last run"
- **vs. Average:** "Five seconds ahead of your average"

The comparison is cumulative — it compares total elapsed time at the current split boundary to the same point in the comparison run(s).

### Example Spoken Cue (Coach Mode)

> "Mile 2. Seven minutes forty-two seconds. Average pace: seven fifty-one per mile. Twelve seconds ahead of your last run. Five seconds ahead of your average."

### UI Elements

- **Route selection sheet:** A "Coach Mode" toggle appears when a route is selected (not for free run).
- **Active run screen:** A small "Coach" badge/button in the stats area. Tapping it toggles coach mode on/off. When active, the badge is highlighted (green). When off, it's dimmed.
- **Split toast:** When coach mode is active, the split toast also shows the comparison delta (e.g., "+0:12" or "-0:05").

### Data Requirements

For each named route, compute:
- **Last run splits:** The split times from the most recent completed run on this route.
- **Average splits:** The average split time at each boundary across all runs on this route.

### Acceptance Criteria

- [ ] Coach mode toggle appears on the route selection sheet when a route is selected.
- [ ] Coach mode can be toggled on/off during an active run.
- [ ] When coach mode is active, split audio cues include comparison to last run.
- [ ] When coach mode is active, split audio cues include comparison to average.
- [ ] Comparisons are cumulative (total time at split N, not individual split time).
- [ ] Split toast shows comparison delta when coach mode is active.
- [ ] Coach mode is only available when running a named route with at least one prior run.
- [ ] If the current run has more splits than the comparison data, comparisons stop gracefully.

### Technical Notes

- Add `isCoachModeEnabled` to `ActiveRunVM`.
- Extend `RouteComparisonVM` (or create a new service) to compute:
  - `lastRunCumulativeSplitTimes: [TimeInterval]` — from the most recent run's splits.
  - `averageCumulativeSplitTimes: [TimeInterval]` — averaged across all runs' splits.
- In `AudioCueService.handleSplit()`, if coach mode is active, append comparison text.
- Pass coach mode state and comparison data from `ActiveRunVM` to `AudioCueService`.
- The existing `routeComparison.paceComparisonDelta` already compares to the benchmark — coach mode extends this to also compare to average and announces it audibly.

---

## 7. Run Summary View — Restyle Action Buttons

### Problem

The action buttons at the bottom of `RunSummaryView` (Name Route, Export GPX, Delete) are styled with `.bordered` button style crammed into a horizontal `HStack`. The text is too large and the layout looks bad on smaller screens.

### Change

Restyle the actions section to use a cleaner, more compact layout:

- Use a vertical list-style layout with standard row height, or a compact icon-forward horizontal layout.
- Reduce text size — use `.font(.subheadline)` or similar.
- Use SF Symbols as the primary visual with a small text label.
- Give the delete button clear destructive styling but keep it compact.

### Design Direction

A clean approach: use a horizontal row of icon-only circular buttons with small labels underneath (similar to the share/copy/delete row in iOS Photos or Contacts). Each button is a circle (44 pt) with the SF Symbol, and a small caption below.

Alternatively, use a `Section`-style grouped list with icon + text rows (like Settings rows) — compact and readable.

### Acceptance Criteria

- [ ] Action buttons are restyled to be visually compact and clean.
- [ ] Text is appropriately sized (not oversized).
- [ ] All three actions (Name Route, Export GPX, Delete) remain functional.
- [ ] Layout works well on all iPhone screen sizes.
- [ ] Delete action still shows a confirmation alert.

---

## 8. Data Model Changes

### New Properties

```swift
// ActiveRunVM
var isCoachModeEnabled: Bool = false
var selectedNamedRoute: NamedRoute?  // route selected before starting

// RouteComparisonVM (or new CoachService)
var lastRunCumulativeSplitTimes: [TimeInterval] = []
var averageCumulativeSplitTimes: [TimeInterval] = []
```

### New Settings Keys

```swift
@AppStorage("coachModeDefault") var coachModeDefault: Bool = true  // remember preference
```

---

*End of PRD v3.*
