# Run Tracker — Product Requirements Document

**Version:** 1.0
**Last updated:** 2026-03-08
**Platform:** iOS 17+, iPhone only
**Tech stack:** Swift, SwiftUI, MapKit, Core Location, Core Motion, SwiftData, AVSpeechSynthesizer
**Target app size:** < 15 MB

---

## Table of Contents

1. [Product Overview](#1-product-overview)
2. [App Architecture](#2-app-architecture)
3. [Data Model Overview](#3-data-model-overview)
4. [Features](#4-features)
   - 4.1 [Start/Stop Run](#41-startstop-run)
   - 4.2 [Pause/Resume](#42-pauseresume)
   - 4.3 [Live Map](#43-live-map)
   - 4.4 [Time, Distance, and Elevation Tracking](#44-time-distance-and-elevation-tracking)
   - 4.5 [Pace Display](#45-pace-display)
   - 4.6 [Splits](#46-splits)
   - 4.7 [Cadence Tracking](#47-cadence-tracking)
   - 4.8 [Unit Preference](#48-unit-preference)
   - 4.9 [Audio Cues](#49-audio-cues)
   - 4.10 [Run Summary](#410-run-summary)
   - 4.11 [Run History](#411-run-history)
   - 4.12 [Named Routes](#412-named-routes)
   - 4.13 [GPX Export](#413-gpx-export)
   - 4.14 [Dark Mode](#414-dark-mode)
   - 4.15 [Offline Map Support](#415-offline-map-support)
5. [Battery Optimization Strategy](#5-battery-optimization-strategy)
6. [v1 Scope vs. Future Enhancements](#6-v1-scope-vs-future-enhancements)

---

## 1. Product Overview

Run Tracker is a native iOS running app that records GPS-tracked runs with live stats, map visualization, and a searchable history. It prioritizes battery efficiency, offline reliability, and a clean SwiftUI interface suitable for glanceable mid-run use and post-run review.

**Primary user:** Recreational to intermediate runners who want a simple, private, on-device run tracker without account creation, subscriptions, or cloud sync.

**Design principles:**

- Glanceable — large, high-contrast text visible at arm's length while running
- Battery-conscious — GPS and sensor usage tuned to minimize drain
- Offline-first — all data stored locally; GPS tracking works without cell signal
- Minimal — no social features, no gamification, no ads in v1

---

## 2. App Architecture

### Pattern: MVVM + Service Layer

```
┌─────────────────────────────────────────────┐
│                   Views                      │
│  (SwiftUI screens, components, overlays)     │
├─────────────────────────────────────────────┤
│                ViewModels                    │
│  ActiveRunVM · RunHistoryVM · SettingsVM     │
│  RunSummaryVM · RouteComparisonVM            │
├─────────────────────────────────────────────┤
│                 Services                     │
│  LocationManager · MotionManager             │
│  AudioCueService · MapTileCacheService       │
│  RunPersistenceService · GPXExportService    │
│  SplitTracker · ElevationFilter              │
├─────────────────────────────────────────────┤
│               SwiftData Store                │
│  Run · Split · RoutePoint · NamedRoute       │
└─────────────────────────────────────────────┘
```

### Key Services

| Service | Responsibility |
|---|---|
| `LocationManager` | Wraps `CLLocationManager`. Manages accuracy modes, background updates, deferred updates. Publishes `CLLocation` stream. |
| `MotionManager` | Wraps `CMPedometer`. Publishes cadence (steps/min) and step count. |
| `SplitTracker` | Monitors cumulative distance, emits split events at each mile/km boundary. |
| `ElevationFilter` | Applies a simple moving average (window = 5) to `CLLocation.altitude` to smooth barometric noise. Tracks cumulative gain/loss. |
| `AudioCueService` | Receives split/distance/pace events, formats speech strings, speaks via `AVSpeechSynthesizer`. |
| `MapTileCacheService` | Pre-fetches and caches `MKTileOverlay` data for offline use. |
| `RunPersistenceService` | CRUD operations on SwiftData models. Handles sort/filter queries for history. |
| `GPXExportService` | Serializes a `Run` and its `RoutePoint`s to GPX XML. Returns a temporary file URL for the share sheet. |

### Navigation Structure

```
TabView
├── Tab 1: Run (ActiveRunView — start, tracking, paused states)
├── Tab 2: History (RunHistoryListView → RunSummaryView)
└── Tab 3: Settings (SettingsView — units, audio cues, map cache, dark mode)
```

---

## 3. Data Model Overview

### SwiftData Entities

```swift
@Model class Run {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var distanceMeters: Double          // always stored in meters
    var durationSeconds: Double         // active running time (excludes pauses)
    var elevationGainMeters: Double
    var elevationLossMeters: Double
    var averagePaceSecondsPerKm: Double?
    var averageCadence: Double?         // steps per minute
    var totalSteps: Int
    var namedRoute: NamedRoute?         // optional relationship

    @Relationship(deleteRule: .cascade)
    var splits: [Split]

    @Relationship(deleteRule: .cascade)
    var routePoints: [RoutePoint]
}

@Model class Split {
    var id: UUID
    var splitIndex: Int                 // 1-based (mile 1, mile 2, …)
    var distanceMeters: Double          // length of this split segment
    var durationSeconds: Double         // time for this split
    var elevationGainMeters: Double
    var elevationLossMeters: Double
    var averageCadence: Double?
    var startDate: Date
    var endDate: Date

    var run: Run?
}

@Model class RoutePoint {
    var id: UUID
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var altitude: Double                // raw altitude from CLLocation
    var smoothedAltitude: Double        // after moving average filter
    var horizontalAccuracy: Double
    var speed: Double                   // m/s from CLLocation
    var distanceFromStart: Double       // cumulative distance at this point

    var run: Run?
}

@Model class NamedRoute {
    var id: UUID
    var name: String
    var createdDate: Date

    @Relationship(deleteRule: .nullify)
    var runs: [Run]
}
```

### Storage Notes

- All distances stored in meters, all durations in seconds. Conversion to display units happens in ViewModels.
- `RoutePoint` is the heaviest entity. At ~1 point/second for a 1-hour run, expect ~3,600 rows per run. Each row is small (~100 bytes), so a year of daily running ≈ 130 MB — well within device storage.
- SwiftData indices on `Run.startDate` and `Run.namedRoute` for fast history queries.

---

## 4. Features

---

### 4.1 Start/Stop Run

#### User Story

> As a runner, I want to tap a single button to begin tracking my run, and tap another button to finish and save it, so that recording a run is effortless.

#### Acceptance Criteria

- [ ] Tapping "Start" begins GPS tracking, timer, cadence, and live stat display.
- [ ] Tapping "Stop" (long-press, 1.5 s) ends the run, stops all tracking, and navigates to the Run Summary screen.
- [ ] The stop action requires a long-press or swipe-to-confirm to prevent accidental taps.
- [ ] A run with zero distance (GPS never acquired) prompts the user: "No distance recorded. Discard this run?" with Discard/Save options.
- [ ] GPS permission is requested on first launch with a clear explanation string. If denied, the Start button shows an inline prompt linking to Settings.
- [ ] The run is persisted to SwiftData before navigating to the summary screen.

#### UI/UX Description

**Pre-run state (ActiveRunView — idle):**

- Large circular "Start" button centered on screen, green.
- Above the button: current GPS signal indicator (icon with 0–3 bars based on `horizontalAccuracy`).
- Below the button: selected unit system label ("miles" or "km").
- Map visible behind the button at reduced opacity showing current location.

**Active run state:**

- The Start button is replaced by the live stats dashboard (see 4.4, 4.5).
- A red "Stop" button appears at the bottom, smaller than Start. Requires long-press — a circular progress ring fills during the hold. If released early, nothing happens.
- A "Pause" button sits adjacent to Stop (see 4.2).

**Transition to summary:**

- On stop, a brief haptic (`.notification(.success)`) fires.
- Screen transitions (push navigation) to RunSummaryView.

#### Technical Implementation Notes

- `LocationManager.startTracking()` sets `desiredAccuracy = kCLLocationAccuracyBest`, `distanceFilter = kCLDistanceFilterNone`, `allowsBackgroundLocationUpdates = true`, `activityType = .fitness`.
- `MotionManager.startCadenceUpdates()` calls `CMPedometer.startUpdates(from:)`.
- On stop: `LocationManager.stopTracking()`, `MotionManager.stopCadenceUpdates()`, persist `Run` via `RunPersistenceService`.
- `CLLocationManager.requestWhenInUseAuthorization()` on first launch. Prompt for "Always" is deferred — not needed in v1 since we use `allowsBackgroundLocationUpdates` with When In Use + background location capability.

#### Edge Cases

- **GPS not acquired after 30 seconds:** Show a banner — "Searching for GPS… Move to an open area." Keep the timer running but do not accumulate distance until first valid fix (horizontalAccuracy < 50 m).
- **User force-quits app during active run:** The run is lost. This is acceptable for v1. Future: periodic auto-save.
- **Location permission denied:** Disable Start button; show inline message with a "Open Settings" link.
- **Very short run (< 10 seconds):** Still save it. The user can delete from history if unintended.

---

### 4.2 Pause/Resume

#### User Story

> As a runner, I want to pause my run when I stop at a traffic light or take a water break, and resume it without losing my progress, so that my pace and time reflect actual running effort.

#### Acceptance Criteria

- [ ] Tapping "Pause" stops the timer and GPS tracking but does not end the run.
- [ ] The paused state is visually distinct from both active and stopped states.
- [ ] Tapping "Resume" restarts the timer and GPS tracking from where they left off.
- [ ] Paused time is excluded from total duration and pace calculations.
- [ ] Distance is not accumulated while paused (GPS updates stop).
- [ ] The user can stop (finish) the run directly from the paused state.
- [ ] If the app is backgrounded while paused, it remains paused indefinitely without draining battery.

#### UI/UX Description

**Paused state:**

- The timer display shows the frozen time with a pulsing animation (opacity oscillation, 1 s period) to indicate the run is paused, not crashed.
- The background color of the stats area shifts to a muted amber/yellow tint.
- The "Pause" button transforms into a green "Resume" button (same position, icon swap with a brief scale animation).
- The "Stop" button remains available and unchanged.
- A "PAUSED" label appears prominently above the timer.
- The map remains visible but the location dot stops updating.

#### Technical Implementation Notes

- On pause: `LocationManager.pauseTracking()` — sets `desiredAccuracy = kCLLocationAccuracyReduced` and stops delivering delegate updates. This allows the system to power down the GPS chip.
- On resume: `LocationManager.resumeTracking()` — restores `kCLLocationAccuracyBest` and resumes delegate delivery.
- `ActiveRunVM` maintains `runState: enum { idle, active, paused }`. Timer is a `Combine` publisher (`Timer.publish(every: 1.0)`) that only increments `elapsedSeconds` when `runState == .active`.
- Cadence updates are also paused/resumed in sync.
- The distance between the last pre-pause point and the first post-resume point is calculated normally, but a flag on `RoutePoint` (`isResumePoint: Bool`) allows the polyline renderer to draw a dotted segment for the gap.

#### Edge Cases

- **User pauses, walks 500 m, resumes:** The GPS will acquire a new position some distance from the pause point. The straight-line distance between last-pre-pause and first-post-resume points is added to total distance. This may slightly overcount if the user backtracked. Acceptable for v1.
- **User pauses for a very long time (hours):** No timeout on pause. The run remains paused until explicitly resumed or stopped. Battery impact is negligible since GPS is powered down.
- **App killed by OS while paused:** Run data up to the pause point is not persisted mid-run in v1. Data is lost. Mitigated in future versions with periodic auto-save.

---

### 4.3 Live Map

#### User Story

> As a runner, I want to see my real-time position on a map with roads, trails, and terrain so I can orient myself and see the route I've taken.

#### Acceptance Criteria

- [ ] The map shows the user's current position with a standard blue dot.
- [ ] The route taken so far is drawn as a colored polyline on the map.
- [ ] The map supports at least two styles: standard (road/street) and hybrid (satellite + labels).
- [ ] The map auto-follows the user's position during an active run (camera centers on the blue dot).
- [ ] The user can pan/zoom the map freely; auto-follow re-engages after 5 seconds of inactivity or when a "Re-center" button is tapped.
- [ ] The polyline updates at a throttled rate (every 3 seconds) to avoid excessive redraws.

#### UI/UX Description

**Layout (active run screen):**

- The map occupies the top ~55% of the screen.
- Stats overlay the bottom ~45% (see 4.4).
- A small map-style toggle button (icon: layered squares) sits in the top-right corner of the map.
- A "Re-center" compass button appears in the top-left when the user has manually panned away.

**Map polyline:**

- Active route: 4 pt stroke, system blue.
- Paused gap segment: 2 pt stroke, dashed, gray.
- Start point: green circle marker.
- Current position: default MKUserLocation blue dot.

**Map style picker:**

- Tapping the toggle cycles through: Standard → Hybrid → Standard.
- The selected style persists via `@AppStorage`.

#### Technical Implementation Notes

- Use SwiftUI `Map` view (iOS 17+) with `MapPolyline` for the route overlay.
- The `ActiveRunVM` maintains a `displayedRouteCoordinates: [CLLocationCoordinate2D]` array, appended to every 3 seconds by batching incoming `RoutePoint` data.
- Camera position managed via `MapCameraPosition`. Set to `.userLocation(followsHeading: false, fallback: .automatic)` when auto-following.
- Map style: `MapStyle.standard(elevation: .realistic)` or `MapStyle.hybrid(elevation: .realistic)`.
- The polyline is a single `MapPolyline(coordinates:)` — rebuilding it every 3 seconds with the full coordinate array is efficient up to thousands of points on modern iPhones.

#### Edge Cases

- **GPS jitter while stationary:** Apply a minimum movement threshold (2 m) before appending a new `RoutePoint`. Prevents the polyline from scribbling at rest.
- **Tunnel or urban canyon (no GPS):** The blue dot may jump. The polyline will show a straight line between the last valid point and the first point after reacquisition. Acceptable for v1.
- **User zooms out to see full route:** Auto-follow disengages. The re-center button appears.
- **Very long run (marathon+):** Thousands of polyline points. Performance tested up to 10,000 points — `MapPolyline` handles this. If issues arise, decimate the coordinate array for display (every Nth point) while keeping full resolution in storage.

---

### 4.4 Time, Distance, and Elevation Tracking

#### User Story

> As a runner, I want to see my elapsed time, total distance, and elevation gain/loss updating live during my run, so I can monitor my effort in real time.

#### Acceptance Criteria

- [ ] Elapsed time displayed in HH:MM:SS format, updating every second.
- [ ] Distance displayed in the user's preferred unit (mi or km), updating with each GPS fix.
- [ ] Elevation gain and elevation loss displayed in the user's preferred unit (ft or m), updating live.
- [ ] All stats are visible simultaneously on the active run screen without scrolling.
- [ ] Elevation values use smoothed altitude data (moving average) to avoid noisy readings.

#### UI/UX Description

**Stats dashboard (bottom 45% of active run screen):**

```
┌────────────────────────────────┐
│        02:34:17                │   ← elapsed time, largest font (48 pt)
├───────────────┬────────────────┤
│   5.23 mi     │   8'12" /mi   │   ← distance (left), avg pace (right)
├───────────────┼────────────────┤
│  ↑ 342 ft     │  ↓ 118 ft     │   ← elev gain (left), elev loss (right)
├───────────────┼────────────────┤
│  7'48" /mi    │   162 spm     │   ← current pace (left), cadence (right)
└───────────────┴────────────────┘
```

- All values use a monospaced or tabular-figure font to prevent layout jitter as digits change.
- Font sizes are large enough to read at arm's length while running (~24 pt for secondary stats).
- Labels are minimal — the unit suffix serves as the label (e.g., "mi", "ft", "/mi").

#### Technical Implementation Notes

- **Time:** `ActiveRunVM.elapsedSeconds` incremented by a `Timer.publish(every: 1.0)` subscription, only when `runState == .active`. Formatted via a `DateComponentsFormatter` with `.positional` style.
- **Distance:** `ActiveRunVM.totalDistanceMeters` accumulated by summing `location.distance(from: previousLocation)` for each valid GPS fix. Converted to miles or km in the View layer.
- **Elevation:** `ElevationFilter` receives each `CLLocation.altitude` and maintains a circular buffer of the last 5 readings. Output = buffer average. Gain/loss calculated by comparing consecutive smoothed values: if delta > +0.5 m → gain; if delta < -0.5 m → loss. The ±0.5 m dead zone filters minor barometric fluctuations.
- **Display updates:** Stats are `@Published` properties on `ActiveRunVM`. SwiftUI redraws only the changed text labels — no expensive view rebuilds.

#### Edge Cases

- **Altitude unavailable (rare on modern iPhones):** Display "—" for elevation fields. Still track distance and time.
- **GPS accuracy too low (> 50 m):** Do not accumulate distance from that fix. Show a "Low GPS" indicator.
- **First GPS fix has wildly wrong altitude:** Discard altitude readings until the moving average buffer is full (5 readings).
- **Runs crossing midnight:** Timer is based on elapsed seconds, not wall clock. No issue.

---

### 4.5 Pace Display

#### User Story

> As a runner, I want to see my current pace and overall average pace during a run so I can manage my effort and maintain a target pace.

#### Acceptance Criteria

- [ ] Current pace updates every ~5 seconds, based on the last ~15 seconds of movement.
- [ ] Average pace updates with each GPS fix, calculated as total elapsed time / total distance.
- [ ] Pace is displayed in min:sec per mile or min:sec per km, depending on unit preference.
- [ ] If the runner is stopped or moving very slowly (< 1 km/h), current pace displays "— —" rather than an absurdly high value.
- [ ] Both pace values are visible on the active run stats dashboard.

#### UI/UX Description

- Current pace: labeled "Pace" in the stats grid, displayed as `M'SS" /mi` (e.g., `7'48" /mi`).
- Average pace: labeled "Avg" in the stats grid, displayed identically.
- Both appear in the stats dashboard (see 4.4 layout).

#### Technical Implementation Notes

- **Current pace:** Calculated from a rolling window. Maintain the last 15 seconds of `RoutePoint` entries. Current pace = (time window in seconds) / (distance across window, converted to miles or km). Recalculate every 5 seconds.
- **Average pace:** `elapsedSeconds / (totalDistanceMeters / 1609.34)` for imperial, or `elapsedSeconds / (totalDistanceMeters / 1000.0)` for metric. Expressed as seconds per unit, formatted as `M'SS"`.
- **Slow/stopped threshold:** If instantaneous speed from `CLLocation.speed` < 0.3 m/s for all points in the rolling window, display "— —" for current pace.

#### Edge Cases

- **First few seconds of a run:** Insufficient data for rolling window. Display "— —" until at least 10 seconds and 10 m of distance have elapsed.
- **Extremely fast pace (< 3 min/mi):** Likely GPS error (e.g., teleporting fix). Cap current pace at a floor of 2'00"/mi (or equivalent in km). Do not cap average pace — it self-corrects over distance.
- **Zero distance run:** Average pace = "— —". Prevent division by zero.

---

### 4.6 Splits

#### User Story

> As a runner, I want automatic split times recorded at every mile or kilometer so I can review my pacing consistency during and after a run.

#### Acceptance Criteria

- [ ] A split is automatically recorded each time cumulative distance crosses a mile or km boundary (based on unit preference).
- [ ] Each split records: split index, duration, distance, elevation gain/loss, and average cadence for that segment.
- [ ] The most recent split is briefly displayed on the active run screen when it triggers (toast notification for ~5 seconds).
- [ ] All splits are viewable in the run summary (see 4.10).
- [ ] An audio cue fires at each split (see 4.9).

#### UI/UX Description

**During run — split toast:**

- When a split boundary is crossed, a banner slides down from the top of the stats area:
  ```
  Mile 3 — 7'42"
  ```
- The banner auto-dismisses after 5 seconds.
- The banner uses a semi-transparent background so underlying stats remain partially visible.

**Run summary — split table:**

| Split | Time   | Pace     | Elev ↑ | Elev ↓ | Cadence |
|-------|--------|----------|--------|--------|---------|
| 1     | 7'42"  | 7'42"/mi | 52 ft  | 12 ft  | 164 spm |
| 2     | 7'55"  | 7'55"/mi | 18 ft  | 44 ft  | 161 spm |
| …     |        |          |        |        |         |

- Fastest split highlighted in green, slowest in red.

#### Technical Implementation Notes

- `SplitTracker` subscribes to the distance stream from `ActiveRunVM`. It maintains `nextSplitBoundary` (e.g., 1609.34 m for mile 1 in imperial). When `totalDistanceMeters >= nextSplitBoundary`, it snapshots the current stats, creates a `Split` object, and fires a split event (via Combine publisher).
- The `Split` entity records the delta values (distance, duration, elevation, cadence) for just that segment, not cumulative.
- The last partial split (e.g., 0.4 mi at the end of a 5.4 mi run) is stored with a flag `isPartial: Bool` and displayed differently in the summary (italicized or grayed out).

#### Edge Cases

- **User changes unit preference mid-run:** Splits already recorded stay as-is. Future splits use the new unit. A note in the summary indicates the unit change. (Unlikely but handled gracefully.)
- **Very short run (< 1 split):** No splits recorded. Summary shows "No full splits" with the partial segment stats.
- **GPS loss causes distance to jump:** A single split could appear anomalously fast. No correction in v1 — the underlying GPS data is what it is.

---

### 4.7 Cadence Tracking

#### User Story

> As a runner, I want to see my step cadence (steps per minute) during my run so I can monitor my running form.

#### Acceptance Criteria

- [ ] Current cadence (steps/min) is displayed live on the active run screen.
- [ ] Average cadence is recorded per split and for the overall run.
- [ ] Cadence uses Core Motion pedometer, not raw accelerometer.
- [ ] Cadence is displayed as an integer (e.g., "164 spm").
- [ ] If pedometer data is unavailable (e.g., permission denied), the cadence field shows "—" and other features are unaffected.

#### UI/UX Description

- Cadence appears in the stats dashboard (bottom-right cell, see 4.4 layout).
- Label: value + "spm" suffix.

#### Technical Implementation Notes

- `MotionManager` calls `CMPedometer.startUpdates(from: startDate)`. The handler receives `CMPedometerData` which includes `currentCadence` (steps/s since iOS 9). Multiply by 60 for spm.
- If `currentCadence` is nil (can happen during walking/standing), display the last known cadence value for up to 10 seconds, then show "—".
- Average cadence per split: sum of (cadence × duration) for each pedometer update in the split window, divided by split duration.
- Requires `NSMotionUsageDescription` in Info.plist.
- `CMPedometer.isStepCountingAvailable()` checked at launch. If false, cadence field is hidden.

#### Edge Cases

- **Motion permission denied:** Cadence field shows "—". No other features affected.
- **Treadmill running (no GPS movement):** Cadence still works (pedometer is motion-based, not GPS-based). Distance and pace will be wrong without GPS — out of scope for v1 treadmill support.

---

### 4.8 Unit Preference

#### User Story

> As a runner, I want to choose between metric and imperial units so that distances, pace, and elevation are displayed in units I'm familiar with.

#### Acceptance Criteria

- [ ] A setting allows the user to choose "Imperial (mi, ft)" or "Metric (km, m)".
- [ ] The preference is persisted across app launches (via `@AppStorage`).
- [ ] All distance, pace, elevation, and split displays respect the selected unit.
- [ ] Changing the preference updates all displayed values immediately, including run history.
- [ ] Default: imperial if device locale is US/UK/MM/LR; metric otherwise.

#### UI/UX Description

**Settings screen:**

- A segmented control labeled "Units" with two options: "Imperial" and "Metric".
- Below the control, a preview line: "Distance: mi · Pace: /mi · Elevation: ft" (updates live with selection).

#### Technical Implementation Notes

- Stored as `@AppStorage("unitSystem") var unitSystem: UnitSystem = .default` where `UnitSystem` is an enum: `.imperial`, `.metric`.
- `.default` computed from `Locale.current.measurementSystem`.
- All internal calculations use SI (meters, seconds). Conversion happens at the View/ViewModel layer via extension methods:
  - `Double.asDistance(unit:) -> String`
  - `Double.asPace(unit:) -> String`
  - `Double.asElevation(unit:) -> String`
- Conversion constants: 1 mi = 1609.344 m, 1 ft = 0.3048 m.

#### Edge Cases

- **User changes units between runs:** History displays adapt. All stored data is in SI, so conversion is lossless.
- **User changes units mid-run:** Live display updates immediately. Splits already recorded are stored in SI and redisplayed in new units. No data loss.

---

### 4.9 Audio Cues

#### User Story

> As a runner, I want spoken audio cues announcing my splits, pace, and distance at each mile/km or at time intervals so I can stay informed without looking at my phone.

#### Acceptance Criteria

- [ ] An audio cue fires at each split boundary (mile or km) announcing: split number, split time, and current average pace.
- [ ] The user can optionally enable time-based cues at configurable intervals (every 1, 5, or 10 minutes).
- [ ] Time-based cues announce: elapsed time, current distance, and current average pace.
- [ ] Audio cues play over music/podcasts (ducking the audio, not pausing it).
- [ ] Audio cues can be toggled on/off in settings. Off by default.
- [ ] Cue language matches device locale (AVSpeechSynthesizer handles this automatically).

#### UI/UX Description

**Settings screen — Audio Cues section:**

- Toggle: "Audio Cues" (on/off).
- When on, sub-options appear:
  - "At each split" (toggle, default on).
  - "At time intervals" (toggle, default off) → picker: 1 min, 5 min, 10 min.

**Example spoken cue (split):**

> "Mile three. Seven forty-two. Average pace: seven fifty-one per mile."

**Example spoken cue (time interval):**

> "Twenty minutes. Three point two miles. Average pace: six fifteen per kilometer."

#### Technical Implementation Notes

- `AudioCueService` subscribes to split events from `SplitTracker` and timer events from `ActiveRunVM`.
- Uses `AVSpeechSynthesizer` with `AVSpeechUtterance`. Set `utterance.rate = AVSpeechUtteranceDefaultSpeechRate`.
- Audio session category: `.playback` with `.duckOthers` option. This lowers background music volume during the cue and restores it after.
- Activate the audio session only when about to speak, deactivate with `.notifyOthersOnDeactivation` after.
- No bundled audio files — all speech is synthesized on-device.

#### Edge Cases

- **User wearing AirPods with music:** Ducking works. Cue plays through the same output route.
- **Silent/vibrate mode:** `AVSpeechSynthesizer` respects the silent switch by default. To override (so cues play even in silent mode), set the audio session category to `.playback` — this is correct behavior since the user explicitly enabled audio cues.
- **Multiple cues fire simultaneously (split + time interval at the same moment):** Queue them. `AVSpeechSynthesizer` queues utterances natively.
- **No speech voice available for locale:** Falls back to en-US. Extremely rare on iOS.

---

### 4.10 Run Summary

#### User Story

> As a runner, I want to see a summary of my run immediately after finishing, showing my route on a map, all stats, splits, and an elevation profile so I can review my performance.

#### Acceptance Criteria

- [ ] The summary screen appears automatically after stopping a run.
- [ ] It displays: date/time, total distance, total duration, average pace, total elevation gain/loss, total steps, average cadence.
- [ ] It shows the full route on a map, fitted to the route bounds with padding.
- [ ] It includes a split table (see 4.6).
- [ ] It includes an elevation profile chart (distance on X-axis, elevation on Y-axis).
- [ ] The user can assign a route name from this screen (see 4.12).
- [ ] The user can share/export as GPX from this screen (see 4.13).
- [ ] The user can delete the run from this screen.

#### UI/UX Description

**RunSummaryView — scrollable, single-column layout:**

1. **Header:** Date + time (e.g., "Sat, Mar 7, 2026 · 6:42 AM"). Optional named route badge.
2. **Stat cards:** 2×2 grid of large stat cards (distance, duration, avg pace, avg cadence). Below: elevation gain/loss in a smaller row.
3. **Route map:** Non-interactive `Map` snapshot showing the full polyline, zoomed to fit. Start = green pin, finish = red pin. Tapping the map opens a full-screen interactive version.
4. **Elevation profile:** A `Chart` (Swift Charts) with distance on X, elevation on Y. Area fill under the line. Colored gradient: green (low) to brown (high).
5. **Splits table:** See 4.6.
6. **Actions row:** Buttons for "Name Route", "Export GPX", "Delete Run".

#### Technical Implementation Notes

- `RunSummaryVM` is initialized with the `Run` model. It computes all display values from the stored data.
- The route map uses `MapPolyline` within a `Map` view, with `.mapCameraPosition` set to `.rect(MKMapRect)` computed from the route bounding box plus 20% padding.
- Elevation profile uses Swift Charts `AreaMark` with `LineMark` overlay. X = `routePoint.distanceFromStart` (converted to user unit). Y = `routePoint.smoothedAltitude` (converted to user unit).
- "Delete Run" triggers a confirmation alert, then calls `RunPersistenceService.delete(run:)` and pops to the history list.

#### Edge Cases

- **Run with no GPS data (permission issue):** Summary shows time and cadence only. Map and elevation sections show "No route data available."
- **Very short run (< 100 m):** All sections still display. The map may be very zoomed in — set a minimum span of 200 m.
- **Elevation profile flat (indoor/treadmill-like):** Chart auto-scales Y-axis. A flat line is expected and fine.

---

### 4.11 Run History

#### User Story

> As a runner, I want to browse my past runs in a list that I can sort and filter so I can track my progress and find specific runs.

#### Acceptance Criteria

- [ ] All completed runs appear in a scrollable list, most recent first by default.
- [ ] Each row shows: date, distance, duration, average pace, and named route (if any).
- [ ] The list is sortable by: date, distance, duration, or average pace (ascending/descending).
- [ ] The list is filterable by: date range, minimum distance, and named route.
- [ ] Tapping a row opens the RunSummaryView for that run.
- [ ] Swipe-to-delete removes a run (with confirmation).
- [ ] Pull-to-refresh is not needed (local data, always fresh).

#### UI/UX Description

**RunHistoryListView:**

- **Top bar:** Title "History" + sort/filter button (funnel icon).
- **Sort/filter sheet:** Bottom sheet with:
  - Sort by: segmented control (Date / Distance / Duration / Pace) + ascending/descending toggle.
  - Filter by date: two date pickers (from/to), defaulting to all time.
  - Filter by distance: minimum distance slider or text field.
  - Filter by route: picker listing all named routes + "All Routes".
  - "Apply" and "Reset" buttons.
- **Run list:** `LazyVStack` or `List` of run row cards.
  - Each card:
    ```
    ┌──────────────────────────────────┐
    │ Sat, Mar 7 · Morning Run Trail   │
    │ 5.23 mi  ·  42:17  ·  8'05"/mi  │
    └──────────────────────────────────┘
    ```
  - If a named route is assigned, it appears after the date. Otherwise, just the date.
- **Empty state:** "No runs yet. Lace up and hit Start!"

#### Technical Implementation Notes

- `RunHistoryVM` uses SwiftData `@Query` with dynamic `SortDescriptor` and `#Predicate`.
- Use `LazyVStack` inside a `ScrollView` (not `List`) for more styling control. Each row is a `NavigationLink` to `RunSummaryView`.
- For performance with hundreds of runs, rely on SwiftData's lazy fetching. No in-memory sorting.
- Swipe-to-delete: `.onDelete` modifier → confirmation alert → `RunPersistenceService.delete(run:)`.

#### Edge Cases

- **Thousands of runs:** SwiftData + lazy list handles this. Tested up to 5,000 rows.
- **All runs deleted:** Show empty state view.
- **Filter returns no results:** Show "No runs match your filters" with a "Reset Filters" button.

---

### 4.12 Named Routes

#### User Story

> As a runner, I want to name a route so I can compare my performance across different runs on the same course.

#### Acceptance Criteria

- [ ] The user can assign a name to a route from the run summary screen.
- [ ] Named routes are reusable — when starting or finishing a run, the user can select an existing named route or create a new one.
- [ ] The run history can be filtered by named route (see 4.11).
- [ ] A "Route Detail" screen shows all runs on a named route, sorted by date, with trend data (best time, best pace, recent performance).
- [ ] Named routes can be renamed or deleted from settings or the route detail screen.
- [ ] Deleting a named route does not delete the runs — it just unlinks them.

#### UI/UX Description

**Assigning a route (from RunSummaryView):**

- "Name Route" button opens a sheet with:
  - Text field for new route name.
  - Below: list of existing named routes for quick selection (if any exist).
  - "Save" button.

**Route Detail screen (from history filter or settings):**

- Header: route name + run count.
- Stats: best time, best pace, average pace, total times run.
- Runs list: all runs on this route, sorted by date descending.
- A small trend chart (Swift Charts): average pace over time (line chart, X = date, Y = pace).

#### Technical Implementation Notes

- `NamedRoute` is a separate SwiftData entity with a one-to-many relationship to `Run` (see data model).
- Route matching is manual (user-assigned), not GPS-based in v1. Automatic route matching (comparing GPS traces) is a future enhancement.
- `NamedRoute.runs` is a SwiftData `@Relationship` with `.nullify` delete rule — deleting the route sets `run.namedRoute = nil`.

#### Edge Cases

- **Duplicate route names:** Allow it (different users may have different naming conventions). The ID is the unique key, not the name.
- **Very long route name:** Cap at 50 characters in the text field.
- **Run assigned to a route, then route deleted:** Run remains, `namedRoute` becomes nil.

---

### 4.13 GPX Export

#### User Story

> As a runner, I want to export any run as a GPX file so I can share it with other apps or services (Strava, Garmin Connect, etc.).

#### Acceptance Criteria

- [ ] An "Export GPX" button is available on the run summary screen.
- [ ] Tapping it generates a GPX 1.1 file with the run's route points (lat, lon, elevation, timestamp).
- [ ] The GPX file is presented via the system share sheet (`UIActivityViewController` / `ShareLink`).
- [ ] The GPX file is valid and parseable by Strava, Garmin Connect, and GPX viewers.
- [ ] The filename follows the format: `RunTracker_YYYY-MM-DD_HHMMSS.gpx`.

#### UI/UX Description

- "Export GPX" button with a share icon (square with upward arrow) in the RunSummaryView actions row.
- Tapping it briefly shows a loading spinner (< 1 second for typical runs), then the share sheet appears.
- Share sheet offers: AirDrop, Files, Mail, Messages, and any installed apps that accept GPX.

#### Technical Implementation Notes

- `GPXExportService.export(run:) -> URL` generates the GPX XML string and writes it to a temporary file in `FileManager.default.temporaryDirectory`.
- GPX structure:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Run Tracker"
     xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>Run on 2026-03-07</name>
    <time>2026-03-07T06:42:00Z</time>
  </metadata>
  <trk>
    <name>Run</name>
    <trkseg>
      <trkpt lat="43.6532" lon="-79.3832">
        <ele>76.4</ele>
        <time>2026-03-07T06:42:00Z</time>
      </trkpt>
      <!-- ... -->
    </trkseg>
  </trk>
</gpx>
```

- Pause gaps: start a new `<trkseg>` after each resume point. This is the standard GPX way to represent discontinuities.
- Use `ISO8601DateFormatter` for timestamps.
- Present via SwiftUI `ShareLink(item: gpxFileURL)`.
- Clean up temp files periodically or on app launch.

#### Edge Cases

- **Run with 10,000+ route points:** GPX file may be 1–2 MB. Generation should still be < 1 second. No issues.
- **Run with no route points:** Export button is hidden or disabled.
- **Special characters in filename:** The date-based filename avoids this.

---

### 4.14 Dark Mode

#### User Story

> As a runner who runs at night or in low-light conditions, I want a dark, high-contrast UI that minimizes screen brightness and glare so I can see my stats without blinding myself.

#### Acceptance Criteria

- [ ] The app supports system dark mode (follows the system setting by default).
- [ ] An in-app override allows the user to force dark mode regardless of system setting.
- [ ] In dark mode, all backgrounds are true black (`#000000`) to minimize OLED power draw.
- [ ] Text and icons use high-contrast colors (white, bright green, bright orange).
- [ ] The map switches to `.standard(emphasis: .muted)` or dark-styled map in dark mode.
- [ ] No white flashes during screen transitions.

#### UI/UX Description

**Settings — Appearance section:**

- Three-way segmented control: "System" / "Light" / "Dark".
- Default: "System".

**Dark mode color palette:**

| Element | Color |
|---|---|
| Primary background | `#000000` (true black) |
| Card/surface background | `#1C1C1E` (system gray 6) |
| Primary text | `#FFFFFF` |
| Secondary text | `#8E8E93` (system gray) |
| Accent (start, distance) | `#30D158` (system green) |
| Warning (stop, slow pace) | `#FF453A` (system red) |
| Timer text | `#FFFFFF` |
| Split toast background | `#2C2C2E` at 90% opacity |

#### Technical Implementation Notes

- Use SwiftUI's `.preferredColorScheme()` modifier at the root `App` level, controlled by the appearance setting in `@AppStorage`.
- All custom colors defined in the asset catalog with light/dark variants, or using SwiftUI's `Color` with adaptive system colors.
- Map in dark mode: `MapStyle.standard(emphasis: .muted)` gives a desaturated, dark-friendly map.
- Avoid any hardcoded white backgrounds — always use `Color(.systemBackground)` or explicit dark colors.

#### Edge Cases

- **User switches appearance mid-run:** All views update immediately. No disruption to tracking.
- **System dark mode + in-app override:** In-app setting wins. If set to "System", follows system.
- **Screenshots in dark mode:** The true black background may blend with phone bezels in screenshots. Not a functional issue.

---

### 4.15 Offline Map Support

#### User Story

> As a trail runner, I want map tiles cached for offline use so that I can see the map even when I have no cell signal, and my GPS tracking continues uninterrupted.

#### Acceptance Criteria

- [ ] GPS tracking works fully offline — no network required for location, distance, or elevation.
- [ ] Previously viewed map tiles are cached and displayed when offline.
- [ ] The user can manually cache a region of map tiles for offline use (pre-download before a run).
- [ ] Cached tiles are stored on-device with a user-visible cache size in settings.
- [ ] The user can clear the tile cache from settings.
- [ ] When back online, the map refreshes with up-to-date tiles if available.

#### UI/UX Description

**Settings — Offline Maps section:**

- "Download Map Area" button → opens a map view where the user can pan/zoom to the desired area and tap "Download".
- A progress bar shows download progress.
- "Cache size: 142 MB" label below.
- "Clear Cache" button (with confirmation).

**During offline run:**

- Cached tiles display normally. Uncached areas show a gray grid with "Map unavailable offline" text.
- A small "Offline" badge appears on the map (airplane icon).

#### Technical Implementation Notes

- MapKit does not provide a public tile-caching API. Two approaches:
  1. **MKTileOverlay with custom URLSession caching:** Create a custom `MKTileOverlay` subclass that uses a `URLSession` with an on-disk `URLCache`. Set a large cache size (e.g., 500 MB). Tiles fetched while online are served from cache when offline.
  2. **Pre-download flow:** For the "Download Map Area" feature, enumerate tile URLs for the visible region at zoom levels 10–16 and prefetch them into the `URLCache`.
- Cache storage: `URLCache(memoryCapacity: 50_000_000, diskCapacity: 500_000_000, directory: cacheURL)`.
- Cache size display: read `URLCache.currentDiskUsage`.
- Clear cache: `URLCache.removeAllCachedResponses()`.
- GPS tracking is fully independent of network — `CLLocationManager` uses the hardware GPS chip directly. This already works offline.
- The route polyline is drawn from local `RoutePoint` data, independent of map tiles. So even if the map background is missing, the route is visible.

#### Edge Cases

- **Map tile cache full (500 MB limit):** Oldest tiles evicted per `URLCache` LRU policy. User can increase limit in a future version.
- **User downloads a large area at high zoom:** Could be hundreds of MB. Show estimated size before confirming download. Cap at zoom level 16 to limit tile count.
- **Flight mode during run:** GPS may take longer for initial fix but works once satellites are locked. Inform user: "GPS may take longer to acquire in airplane mode."
- **MapKit internals bypass custom cache:** If Apple changes MapKit tile loading internals, the cache strategy may break. Mitigation: test with each iOS update. Alternative future approach: bundle third-party tile data.

---

## 5. Battery Optimization Strategy

| Strategy | Implementation | Impact |
|---|---|---|
| **GPS accuracy management** | `kCLLocationAccuracyBest` only during active tracking. Switch to `kCLLocationAccuracyReduced` (or stop updates entirely) when paused/stopped. | Major — GPS is the primary battery consumer. |
| **Deferred location updates** | Call `allowDeferredLocationUpdates(untilTraveled:timeout:)` where available. Lets the GPS chip batch fixes and wake the CPU less often. | Moderate — reduces CPU wake-ups during background tracking. |
| **GPS update throttling** | `distanceFilter = kCLDistanceFilterNone` with manual throttling in the delegate: discard updates arriving faster than 1/second. | Minor — prevents CPU thrash from burst updates. |
| **Pedometer over accelerometer** | Use `CMPedometer` (coprocessor-driven) instead of `CMMotionManager` accelerometer polling. | Moderate — pedometer uses the low-power M-series chip. |
| **Map redraw throttling** | Update the `MapPolyline` overlay every 3 seconds, not every GPS fix. | Minor — reduces GPU work for map rendering. |
| **Audio session management** | Activate `AVAudioSession` only when speaking a cue, deactivate immediately after. | Minor — avoids holding an audio session open continuously. |
| **No background fetch/audio** | Only `location` background mode enabled. No background audio, fetch, or processing modes. | Moderate — prevents unnecessary background wake-ups. |
| **SwiftUI efficiency** | Use `@Observable` (iOS 17), fine-grained property tracking, `LazyVStack` for lists. | Minor — reduces CPU from UI updates. |
| **Display** | Encourage dark mode for OLED power savings. Large, sparse UI minimizes pixel illumination. | Minor (device-dependent). |

**Target:** < 10% battery per hour of active tracking on iPhone 14 and newer (comparable to Apple Workouts).

---

## 6. v1 Scope vs. Future Enhancements

### In v1

- All 15 features described in Section 4.
- iPhone-only, iOS 17+.
- Local storage only (SwiftData), no cloud sync.
- No user accounts or social features.
- No Apple Watch companion.
- No treadmill/indoor run mode.
- No automatic route matching (manual naming only).
- No heart rate integration (requires Watch or Bluetooth HR strap).
- No workout integration with Apple Health (HealthKit).

### Future Enhancements (v2+)

| Feature | Notes |
|---|---|
| **HealthKit integration** | Write runs to Apple Health, read resting heart rate. Requires `NSHealthShareUsageDescription`. |
| **Apple Watch companion** | Wrist-based controls, heart rate, haptic cues. WatchKit + WatchConnectivity. |
| **Cloud sync** | Sync runs across devices via CloudKit. SwiftData supports CloudKit backends natively. |
| **Auto route matching** | Compare GPS traces to automatically suggest a named route when a run follows a known path. Use Hausdorff distance or similar metric. |
| **Treadmill mode** | Use pedometer-only distance estimation when GPS is unavailable or the user selects indoor mode. |
| **Interval training** | Programmable work/rest intervals with audio cues and automatic lap tracking. |
| **Heart rate zones** | Bluetooth HR strap support via CoreBluetooth. Display HR zone and time-in-zone. |
| **Social / sharing** | Share run summaries as images to social media. Leaderboards for named routes. |
| **Strava / Garmin sync** | Direct API integration to upload runs without manual GPX export. |
| **Widgets** | Lock screen and home screen widgets showing weekly mileage, streak, or last run. |
| **Live Activities** | Dynamic Island / lock screen live activity showing pace and distance during a run. |
| **Elevation-adjusted pace** | Grade-adjusted pace (GAP) to normalize pace for hilly terrain. |
| **Training log / calendar** | Weekly/monthly mileage view, training load tracking, rest day suggestions. |
| **Multi-sport** | Cycling, hiking, walking modes with appropriate metrics. |
| **Siri / Shortcuts integration** | "Hey Siri, start a run" via App Intents. |

---

*End of PRD.*
