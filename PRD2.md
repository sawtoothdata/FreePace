# Run Tracker — Product Requirements Document v2

**Version:** 2.0
**Last updated:** 2026-03-08
**Builds on:** PRD v1 (Phases 1–5 complete, Phase 6 deferred)
**Platform:** iOS 17+, iPhone only
**Tech stack:** Swift, SwiftUI, MapKit, Core Location, Core Motion, SwiftData, AVSpeechSynthesizer

---

## Table of Contents

1. [Overview](#1-overview)
2. [Bug Fixes](#2-bug-fixes)
   - 2.1 [Stop Button — Remove Long Press](#21-stop-button--remove-long-press)
   - 2.2 [Larger Stop/Pause Buttons](#22-larger-stoppause-buttons)
   - 2.3 [Completed Runs Not Appearing in History](#23-completed-runs-not-appearing-in-history)
   - 2.4 [Audio Cues Not Firing](#24-audio-cues-not-firing)
3. [UI Improvements](#3-ui-improvements)
   - 3.1 [Settings — Configurable Units and Split Distance](#31-settings--configurable-units-and-split-distance)
   - 3.2 [App Icon](#32-app-icon)
   - 3.3 [Live Map — Center on Runner with Adjustable Zoom](#33-live-map--center-on-runner-with-adjustable-zoom)
   - 3.4 [Named Route — Toggle Current Position vs Route View](#34-named-route--toggle-current-position-vs-route-view)
   - 3.5 [Offline Maps — Named Routes Only](#35-offline-maps--named-routes-only)
4. [New Features](#4-new-features)
   - 4.1 [Named Route Caching with Overlay Trail and Benchmarks](#41-named-route-caching-with-overlay-trail-and-benchmarks)
   - 4.2 [Elevation Visualization on Live Map](#42-elevation-visualization-on-live-map)
   - 4.3 [Elevation-Colored Trail with Time Markers](#43-elevation-colored-trail-with-time-markers)

---

## 1. Overview

PRD v2 addresses bugs and usability issues discovered during initial testing, adds configurable settings, and introduces route overlay and elevation visualization features. Phase 6 (Integration & Edge Cases) from PRD v1 is deferred to a later release.

---

## 2. Bug Fixes

---

### 2.1 Stop Button — Remove Long Press

#### Problem

The stop button currently requires a 1.5-second long press. During a run when the user is fatigued and possibly shaking, a long press is unreliable and frustrating.

#### Change

Replace the long-press stop button with a normal tap button that triggers a confirmation dialog: **"End this run?"** with **End Run** (destructive) and **Cancel** options.

#### Acceptance Criteria

- [ ] Tapping Stop shows a confirmation alert.
- [ ] Confirming ends the run and navigates to the summary screen.
- [ ] Canceling dismisses the alert with no state change.
- [ ] The LongPressButton component is removed or deprecated.

#### Technical Notes

- Replace `LongPressButton` usage in `ActiveRunView` with a standard `Button` + `.alert()` modifier.
- The haptic feedback (`.notification(.success)`) fires on confirmation, not on tap.

---

### 2.2 Larger Stop/Pause Buttons

#### Problem

The stop and pause buttons are too small to hit reliably while running and fatigued.

#### Change

Increase the minimum tap target for stop and pause buttons to **at least 64×64 pt** (ideally 72×72 pt). Use bold iconography and high-contrast colors.

#### Acceptance Criteria

- [ ] Stop button is at least 64 pt tall and wide.
- [ ] Pause/Resume button is at least 64 pt tall and wide.
- [ ] Buttons are easy to tap one-handed while running.
- [ ] Button layout does not obscure stats or map.

#### Technical Notes

- Update button frames and padding in `ActiveRunView` active and paused states.
- Consider placing buttons in a fixed bottom toolbar with generous spacing.

---

### 2.3 Completed Runs Not Appearing in History

#### Problem

After stopping a run, the completed run does not appear in the run history list.

#### Change

Ensure the run is persisted to SwiftData before navigating to the summary screen, and that `RunHistoryVM` picks up newly saved runs.

#### Acceptance Criteria

- [ ] A completed run appears in the History tab immediately after being stopped.
- [ ] The run persists across app restarts.
- [ ] Navigating from the summary back to the history tab shows the run.

#### Technical Notes

- Debug the `stopRun()` flow in `ActiveRunVM` — verify `RunPersistenceService.save()` is called and the `ModelContext` is saved.
- Verify `RunHistoryVM` re-queries or observes the SwiftData store for changes.
- Check that the `Run` object has `endDate` set and is not filtered out by any default predicate.

---

### 2.4 Audio Cues Not Firing

#### Problem

Time-based audio cues (e.g., every 1 minute) produce no sound or speech during a run. The feature appears completely non-functional.

#### Expected Behavior

When audio cues are enabled with timed intervals, the app should speak an update at each interval containing:
- **Current elapsed time**
- **Current distance**
- **Overall average pace**
- **Pace of the last completed split**

#### Acceptance Criteria

- [ ] Time-based audio cues fire at the configured interval (1, 5, or 10 minutes).
- [ ] Each cue announces: elapsed time, distance, overall pace, and last split pace.
- [ ] Cues are audible over music/podcasts (audio ducking works).
- [ ] Cues work when the app is in the background (screen locked).
- [ ] Split-based cues also announce last split pace (in addition to existing info).

#### Example Spoken Cue (timed)

> "Ten minutes. One point five miles. Average pace: eight twelve per mile. Last split: seven fifty-eight per mile."

#### Technical Notes

- Debug `AudioCueService` timer subscription — likely the timer publisher is not connected to `ActiveRunVM` state changes, or the audio session is not activated.
- Verify `AVAudioSession` category is `.playback` with `.duckOthers` and is activated before speaking.
- Verify `AVSpeechSynthesizer` is retained (not deallocated) during the run.
- Add last split pace to the utterance text builder.
- Ensure the timer-based cue subscriber fires even when the app is backgrounded.

---

## 3. UI Improvements

---

### 3.1 Settings — Configurable Units and Split Distance

#### Change

Extend the settings screen to allow the user to choose:
1. **Unit system:** Imperial / Metric (existing)
2. **Split distance:** Configurable options based on unit system:
   - Imperial: 1/4 mi, 1/2 mi, 1 mi
   - Metric: 1/4 km, 1/2 km, 1 km

#### Acceptance Criteria

- [ ] Settings screen shows a split distance picker below the unit selector.
- [ ] The picker options update when the unit system changes.
- [ ] The selected split distance is persisted via `@AppStorage`.
- [ ] `SplitTracker` uses the configured split distance instead of the hardcoded 1 mi / 1 km.
- [ ] Split toasts and the split table reflect the chosen distance.
- [ ] Default split distance: 1 mi (imperial) or 1 km (metric).

#### Technical Notes

- Add a `SplitDistance` enum with cases for each option, storing the distance in meters internally.
- Update `SplitTracker` to accept the split distance as a parameter.
- Update `SettingsVM` and `SettingsView` with the new picker.
- The split table header should reflect the chosen unit (e.g., "1/2 mi" instead of "Mile").

---

### 3.2 App Icon

#### Change

Add an app icon for the home screen. The icon should convey running/fitness with a clean, modern design.

#### Design Direction

- Simple silhouette or abstract running figure
- Use the app's accent green color (`#30D158`) as the primary color
- Dark background for contrast
- No text in the icon
- Provide all required sizes for App Store and device icons (1024×1024 base)

#### Acceptance Criteria

- [ ] App icon appears on the home screen and in the app switcher.
- [ ] Icon is provided at all required resolutions in the asset catalog.
- [ ] Icon follows Apple's Human Interface Guidelines (no transparency, rounded corners applied by OS).

#### Technical Notes

- Add icon images to `Assets.xcassets/AppIcon.appiconset`.
- Generate all required sizes from a 1024×1024 source image.
- The icon can be created programmatically (e.g., using a SwiftUI view rendered to an image) or provided as a PNG asset.

---

### 3.3 Live Map — Center on Runner with Adjustable Zoom

#### Change

For new (non-named) routes, the live map during an active run should:
- Always be centered on the runner's current position
- Allow the user to adjust the zoom level (pinch or +/- buttons)
- Remember the user's preferred zoom level

#### Acceptance Criteria

- [ ] Map stays centered on the runner during an active run (for new routes).
- [ ] User can pinch-to-zoom without losing centering.
- [ ] Zoom level is preserved when the map re-centers.
- [ ] A zoom control (+ / - buttons) is available on the map.
- [ ] The preferred zoom level persists across runs via `@AppStorage`.

#### Technical Notes

- Use `MapCameraPosition` with `.userLocation` and a configurable zoom/span.
- Track the user's zoom level and apply it when re-centering.
- Add +/- buttons as a `VStack` overlay on the map.

---

### 3.4 Named Route — Toggle Current Position vs Route View

#### Change

When running a named route, provide a toggle to switch the map between:
1. **Runner view:** Centered on current position (same as new route behavior)
2. **Route view:** Zoomed out to show the full named route overlay with the runner's current position marked

#### Acceptance Criteria

- [ ] A toggle button appears on the map when running a named route.
- [ ] "Runner" mode centers on the runner with the user's zoom level.
- [ ] "Route" mode fits the full named route in view with the runner's position visible.
- [ ] The route overlay (from the named route's best run) is visible in both modes.
- [ ] Switching modes is smooth (animated camera transition).

#### Technical Notes

- The toggle only appears when `ActiveRunVM` has an associated `NamedRoute`.
- Route view uses `MapCameraPosition.rect()` computed from the named route's bounding box.
- The named route overlay polyline is drawn in a distinct style (e.g., dashed gray) separate from the active run polyline.

---

### 3.5 Offline Maps — Named Routes Only

#### Change

Restrict offline map caching to named routes only. Remove the general "Download Map Area" flow. When a user creates or runs a named route, the map tiles for that route's region are automatically cached.

#### Acceptance Criteria

- [ ] Map tiles for named route regions are automatically cached after a run is assigned to a route.
- [ ] The "Download Map Area" manual flow is removed from settings.
- [ ] Settings still shows cache size and a "Clear Cache" button.
- [ ] When running a named route offline, cached tiles display correctly.
- [ ] General (non-named-route) runs show the standard "Map unavailable offline" placeholder when offline.

#### Technical Notes

- After a run is assigned to a named route, trigger a background tile prefetch for the route's bounding box at zoom levels 10–16.
- Remove the manual download map UI from `SettingsView`.
- Keep `MapTileCacheService` but simplify its API to `cacheRoute(_: NamedRoute)`.

---

## 4. New Features

---

### 4.1 Named Route Caching with Overlay Trail and Benchmarks

#### User Story

> As a runner with regular routes, I want to see a cached map with my route trail overlaid and timing benchmarks so I can pace myself against previous runs.

#### Description

When running a named route, display:
1. **Route overlay:** The GPS trail from the best (or most recent) run on this route, drawn as a reference line on the map.
2. **Timing benchmarks:** Markers along the route at each split point showing the best split time at that point.
3. **Live comparison:** The runner's current position on the route with a simple ahead/behind indicator compared to the benchmark run.

#### Acceptance Criteria

- [ ] Named routes display a reference trail overlay from the benchmark run (best time by default).
- [ ] Split point markers appear along the route at each split boundary.
- [ ] Each marker shows the benchmark split time.
- [ ] A simple ahead/behind time indicator shows how the current run compares to the benchmark at the most recent split.
- [ ] The benchmark run can be selected (best time or most recent) in route settings.

#### UI/UX Description

- Route overlay: 3 pt dashed line, light gray or semi-transparent blue.
- Split markers: small circular pins with the split time (e.g., "7:42") displayed in a callout.
- Ahead/behind indicator: a banner or badge showing "+0:23" (behind) in red or "-0:15" (ahead) in green, positioned near the timer.

#### Technical Notes

- Store the benchmark run's route points and split data with the `NamedRoute` (or reference a specific `Run` as the benchmark).
- `RouteComparisonVM` computes the delta between current split times and benchmark split times.
- The overlay polyline is built from the benchmark run's `routePoints`.
- Split markers are `Annotation` views on the `Map` at the coordinates where each split occurred in the benchmark run.

---

### 4.2 Elevation Visualization on Live Map

#### User Story

> As a runner, I want to see elevation changes visually on my live top-down map so I can anticipate hills and understand the terrain ahead.

#### Description

Show elevation change on the live map using visual indicators. Two approaches (can be combined):

1. **Color-coded polyline:** The active run trail changes color based on elevation — green at low points, transitioning through yellow/orange to brown/red at high points. The gradient is relative to the min/max elevation of the current run.
2. **Gradient shading on named routes:** For named routes with cached elevation data, subtle shading or contour hints along the route preview.

#### Acceptance Criteria

- [ ] The active run polyline is color-coded by elevation (green = low, brown/red = high).
- [ ] The color scale is relative to the run's min/max elevation range.
- [ ] Color transitions are smooth (per-segment coloring, not abrupt changes).
- [ ] A small legend or gradient bar indicates the elevation range and color mapping.
- [ ] Performance remains smooth with thousands of route points.

#### Technical Notes

- Use multiple `MapPolyline` segments, each with a color determined by the average elevation of that segment's route points.
- Segment the route into groups of ~5 points, compute average smoothed altitude, map to a color using a gradient.
- Color mapping: normalize elevation to 0–1 range based on `(altitude - minAlt) / (maxAlt - minAlt)`, then interpolate through a green → yellow → orange → brown gradient.
- Alternative: use `MKGradientPolylineRenderer` if dropping down to UIKit for the map layer.
- Update the colored segments every 3 seconds alongside the regular polyline update.

---

### 4.3 Elevation-Colored Trail with Time Markers

#### User Story

> As a runner, I want to see my run trail color-coded for elevation with periodic time markers so I can review my pacing across terrain changes.

#### Description

On the live map during a run, and on the run summary map:
1. **Elevation-colored trail:** Same as 4.2 — the route polyline uses elevation-based coloring.
2. **Time markers:** Drop a marker on the map at configurable intervals (default every 5 minutes). Each marker shows the elapsed time at that point.

#### Acceptance Criteria

- [ ] Time markers appear on the map at the configured interval during the run.
- [ ] Each marker displays the elapsed time (e.g., "10:00", "15:00").
- [ ] The marker interval is configurable in settings (1, 2, 5, 10 minutes).
- [ ] Markers appear on both the live map and the run summary map.
- [ ] Markers do not obscure the route polyline or other map elements.

#### UI/UX Description

- Time markers: small circular pins (12 pt diameter) with a time label below.
- Pin color: white with a dark border for visibility on any map background.
- At high zoom, markers show the time label. At low zoom, just the pin (label hidden to avoid clutter).

#### Technical Notes

- `ActiveRunVM` maintains a `timeMarkers: [(coordinate: CLLocationCoordinate2D, elapsedTime: TimeInterval)]` array.
- Every N minutes of active running time, snapshot the current location and elapsed time.
- Render markers as `Annotation` views on the `Map`.
- Add a `timeMarkerInterval` setting to `SettingsVM` stored in `@AppStorage`.
- On the summary map, markers are computed from `routePoints` by finding points closest to each time interval.

---

## 5. Data Model Changes

### New/Modified Entities

```swift
// Add to NamedRoute
extension NamedRoute {
    var benchmarkRunID: UUID?           // reference run for pace comparison
    var cachedBoundingBox: MKMapRect?   // for tile caching and route view
}

// Add to Split (if not already present)
extension Split {
    var splitDistanceMeters: Double     // configurable split distance used
}
```

### New Settings Keys

```swift
@AppStorage("splitDistance") var splitDistance: String = "full"  // "quarter", "half", "full"
@AppStorage("mapZoomLevel") var mapZoomLevel: Double = 0.01     // map span in degrees
@AppStorage("timeMarkerInterval") var timeMarkerInterval: Int = 5  // minutes
```

---

## 6. Deferred from PRD v1

Phase 6 (Integration & Edge Cases) from PRD v1 is deferred to a future release:
- 6.1 GPS edge cases
- 6.2 Zero-distance run handling
- 6.3 Permission flows
- 6.4 Battery optimization audit
- 6.5 Info.plist and capabilities
- 6.6 Final integration test

These will be addressed in a future PRD alongside any issues discovered during PRD v2 work.

---

*End of PRD v2.*
