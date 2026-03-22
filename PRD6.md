# FreePace UI Improvements Plan

## Context
User has identified 16 UI improvements across the Run Summary and Active Running views after real-world usage. Issues range from quick label fixes to new features (configurable audio cues, pace visualization). Grouped into 7 phases ordered by complexity and dependency.

---

## Phase 1: Quick Label & Style Fixes

### 1A. Move "Save Named Route" to top, relabel "Save Route"
- **File:** [RunSummaryView.swift](Run-Tracker/Run-Tracker/Views/RunSummaryView.swift)
- Move button from `actionsSection` (bottom) to top of ScrollView, after the header/route info
- Change label from `"Save Named Route"` to `"Save Route"`
- Use a compact toolbar-style button (e.g., `.buttonStyle(.bordered)` with smaller control size)

### 1B. Reset voice to default premium
- **File:** [AudioCueService.swift](Run-Tracker/Run-Tracker/Services/AudioCueService.swift)
- Remove `utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.93` → use `AVSpeechUtteranceDefaultSpeechRate`
- Remove `utterance.pitchMultiplier = 1.05` (defaults to 1.0)
- Keep premium voice selection logic (locale-aware fallback) unchanged

### 1C. Rename "Cool Down" → "Walking"
- **File:** [ActiveRunView.swift](Run-Tracker/Run-Tracker/Views/ActiveRunView.swift) line 958
  - `"Cool Down"` → `"Walking"` in button label
- **File:** [ActiveRunVM.swift](Run-Tracker/Run-Tracker/ViewModels/ActiveRunVM.swift) ~line 498
  - `"Cool down started."` → `"Walking started."` in audio cue
- **File:** [AudioCueService.swift](Run-Tracker/Run-Tracker/Services/AudioCueService.swift)
  - Update any `"Cool down"` prefix text to `"Walking"`
- **File:** [SplitTableView.swift](Run-Tracker/Run-Tracker/Views/Components/SplitTableView.swift)
  - Walking icon label already uses `figure.walk`, no change needed
- **File:** [RunSummaryView.swift](Run-Tracker/Run-Tracker/Views/RunSummaryView.swift)
  - Rename any "Running" / "Cool-Down" section headers to "Running" / "Walking"

---

## Phase 2: Running/Walking Time & Metrics

### 2A. Show run time and walk time separately
- **File:** [RunSummaryVM.swift](Run-Tracker/Run-Tracker/ViewModels/RunSummaryVM.swift)
  - Already has `runningOnlyDurationSeconds` and `coolDownDurationSeconds`
  - Add formatted properties for walk distance and walk duration
- **File:** [RunSummaryView.swift](Run-Tracker/Run-Tracker/Views/RunSummaryView.swift)
  - When `run.hasCoolDown`, show a "Walking" subsection with walk distance and walk duration stat cards alongside the existing "Running" section

### 2B. Track time to first walk
- **File:** [Run.swift](Run-Tracker/Run-Tracker/Models/Run.swift)
  - Add `var timeToFirstWalkSeconds: Double? = nil` (SwiftData handles nil default gracefully, no migration needed)
- **File:** [ActiveRunVM.swift](Run-Tracker/Run-Tracker/ViewModels/ActiveRunVM.swift)
  - Add `private var timeToFirstWalkSeconds: Double?`
  - In `toggleCoolDown()`: when `isCoolDownActive` becomes `true` and `timeToFirstWalkSeconds == nil`, set it to `elapsedSeconds`
  - In `stopRun()`: set `run.timeToFirstWalkSeconds = timeToFirstWalkSeconds`
- **File:** [RunSummaryVM.swift](Run-Tracker/Run-Tracker/ViewModels/RunSummaryVM.swift)
  - Add formatted `timeToFirstWalk` computed property
- **File:** [RunSummaryView.swift](Run-Tracker/Run-Tracker/Views/RunSummaryView.swift)
  - Display "Time to First Walk" stat card in Running section when available

### 2C. Show running + walking tabs during active run
- **File:** [ActiveRunView.swift](Run-Tracker/Run-Tracker/Views/ActiveRunView.swift) line 631
  - Change condition from `viewModel.isCoolDownActive || activeRunStatDisplay == "runningOnly"` to `viewModel.hadCoolDownDuringRun` so the picker persists once walking is first used
- **File:** [ActiveRunVM.swift](Run-Tracker/Run-Tracker/ViewModels/ActiveRunVM.swift)
  - Change `hadCoolDownDuringRun` from `private` to `private(set)` to expose to view

---

## Phase 3: Split Table Improvements

### 3A. Split labels show cumulative distance
- **File:** [RunSummaryVM.swift](Run-Tracker/Run-Tracker/ViewModels/RunSummaryVM.swift)
  - Add `cumulativeDistanceMeters: Double` field to `SplitDisplayData`
  - Compute as running sum of `split.distanceMeters` during split-building loop
- **File:** [SplitTableView.swift](Run-Tracker/Run-Tracker/Views/Components/SplitTableView.swift) line 109-112
  - Change `splitLabel(for:)` from `"\(label) \(split.index)"` to formatted cumulative distance
  - Example: with 0.25km splits → "0.25 km", "0.50 km", "0.75 km" instead of "¼ km 1", "¼ km 2", "¼ km 3"

### 3B. View splits including/excluding walking segments
- **File:** [RunSummaryView.swift](Run-Tracker/Run-Tracker/Views/RunSummaryView.swift)
  - Add `@State private var showWalkingSplits: Bool = true`
  - When `run.hasCoolDown`, add a segmented Picker ("All" / "Running Only") above the split table
  - Filter splits passed to `SplitTableView` based on selection
  - Recalculate fastest/slowest indices for filtered set

### 3C. Consistent elevation gain/loss display
- **File:** [RunSummaryVM.swift](Run-Tracker/Run-Tracker/ViewModels/RunSummaryVM.swift)
  - Add `runningOnlyElevationLossMeters` computed property (sum `elevationLossMeters` from non-walking splits)
- **File:** [RunSummaryView.swift](Run-Tracker/Run-Tracker/Views/RunSummaryView.swift)
  - In the Running section, show both ↑ Gain and ↓ Loss (currently only shows gain)
  - Match the format used in the Total section (same layout, toggle between Running/Total)

---

## Phase 4: Map Improvements

### 4A. Freeze map zoom during active run
**Problem:** `centerOnRunner()` reads `mapZoomLevel` from `@AppStorage` and resets the map span on every coordinate update. If the user pinch-zooms, it snaps back.

- **File:** [ActiveRunView.swift](Run-Tracker/Run-Tracker/Views/ActiveRunView.swift)
  - Add `@State private var liveZoomSpan: Double?` for in-run zoom tracking
  - On run start: `liveZoomSpan = mapZoomLevel`
  - `centerOnRunner()` (line 568): use `liveZoomSpan ?? mapZoomLevel` instead of `mapZoomLevel`
  - `reCenter()` (line 992): same change
  - `centerOnRunnerForced()` (line 1016): same change
  - `zoomIn()`/`zoomOut()` (lines 1004-1012): update `liveZoomSpan` instead of `mapZoomLevel`
  - `onMapCameraChange` (line 554-555): update `liveZoomSpan` instead of `mapZoomLevel`
  - Only persist `liveZoomSpan` → `mapZoomLevel` on run end
  - Result: user zoom is preserved; map only follows position, not zoom level

### 4B. Enable interactive zoom on summary map
- **File:** [RunSummaryView.swift](Run-Tracker/Run-Tracker/Views/RunSummaryView.swift)
  - Remove `.allowsHitTesting(false)` from the map
  - Change `Map(initialPosition:)` to `Map(position: $mapPosition)` with `@State` binding
  - Add `.mapControls { MapCompass(); MapScaleView() }` for pinch-to-zoom UX

---

## Phase 5: Audio Cue Configuration

### 5A. Configurable split audio cue content
- **New file:** `Models/AudioCueConfig.swift` (add to pbxproj)
  - Define `AudioCueField` enum cases: `totalDistance`, `totalTime`, `splitTime`, `splitPace`, `totalPace`
  - Store enabled fields as a comma-separated `@AppStorage` string (simpler than OptionSet for AppStorage)
  - Default: all fields enabled
- **File:** [SettingsView.swift](Run-Tracker/Run-Tracker/Views/SettingsView.swift)
  - In `audioCuesSection`, when `cueAtSplits` is on, add `DisclosureGroup("Split Info")` with toggles:
    - Total Distance, Total Time, Split Time, Split Pace, Average Pace
  - Similarly for time interval cues
- **File:** [AudioCueService.swift](Run-Tracker/Run-Tracker/Services/AudioCueService.swift)
  - Add `var enabledSplitFields: Set<AudioCueField>`
  - In `handleSplit()`: conditionally include each text segment based on enabled fields
  - In time interval cue: same conditional assembly
- **File:** [ActiveRunView.swift](Run-Tracker/Run-Tracker/Views/ActiveRunView.swift)
  - Read `@AppStorage` for cue fields and pass to `syncAudioCueSettings()`

### 5B. Configurable coach mode audio cue content
- Same settings infrastructure as 5A
- Additional coach-specific fields: `paceVsLastRun`, `paceVsAverage`, `timeVsLastRun`, `timeVsAverage`
- **File:** [SettingsView.swift](Run-Tracker/Run-Tracker/Views/SettingsView.swift)
  - Add "Coach Mode Info" `DisclosureGroup` with toggles for comparison fields
- **File:** [AudioCueService.swift](Run-Tracker/Run-Tracker/Services/AudioCueService.swift)
  - In coach comparison text builder: conditionally include each comparison

---

## Phase 6: Pace Visualization on Map

### 6A. Pace vs elevation color toggle (active run)
- **New file:** `Extensions/PaceColor.swift` (add to pbxproj)
  - Mirror `ElevationColor` structure
  - Color gradient: green (fast) → yellow (medium) → red (slow)
  - `static func buildSegments(from:)` → reuse `ElevationRouteSegment` type
  - Normalize pace across the run's min/max pace range
- **File:** [ActiveRunVM.swift](Run-Tracker/Run-Tracker/ViewModels/ActiveRunVM.swift)
  - Add `private(set) var paceRouteSegments: [ElevationRouteSegment] = []`
  - Compute pace segments alongside elevation segments during location updates
  - Use per-point speed (available from CLLocation) or inter-point distance/time
  - Expose `paceRange: (min: Double, max: Double)` for legend
- **File:** [ActiveRunView.swift](Run-Tracker/Run-Tracker/Views/ActiveRunView.swift)
  - Add `@State private var mapColorMode: MapColorMode = .elevation` enum (`.elevation`, `.pace`)
  - Add toggle button in map overlay area (near existing map style toggle)
  - Swap between `elevationRouteSegments` and `paceRouteSegments` based on mode
  - Update legend to show pace values when in pace mode

### 6B. Pace visualization on summary map (brainstorm answer)
- True 3D extrusion is **not possible** with SwiftUI's `Map` — MapKit for SwiftUI doesn't support SceneKit custom overlays
- **Recommended approach:** Apply the same pace-colored polyline from 6A to the summary map with a toggle
- **File:** [RunSummaryVM.swift](Run-Tracker/Run-Tracker/ViewModels/RunSummaryVM.swift)
  - Add `paceRouteSegments` computed from route points with speed data
- **File:** [RunSummaryView.swift](Run-Tracker/Run-Tracker/Views/RunSummaryView.swift)
  - Add elevation/pace toggle overlay on the summary map
  - Swap segment source based on selection
- **Future idea:** A combined elevation profile chart with pace-colored line (elevation on Y-axis, pace as color) would give the "pace on hills" insight without needing 3D

---

## Phase 7: Location Tracking Lifecycle Optimization

### 7A. Stop location updates when not on landing page or active run
**Problem:** `initializeLocation()` calls `locationProvider.startTracking()` when the idle view appears, but location updates are never stopped when navigating to other tabs (History, Settings) or after a run completes and the user views the summary. GPS stays active unnecessarily, draining battery.

**Desired behavior:** Location updates should ONLY be active when:
1. The user is on the landing/idle page (Run tab with map background + Start button) — needed for GPS signal indicator and map centering
2. During an active or paused run — needed for route tracking

Location should STOP when:
- User switches to History/Runs tab
- User switches to Settings tab
- User is viewing a Run Summary after completing a run
- Any other non-run screen

**Implementation:**
- **File:** [ActiveRunView.swift](Run-Tracker/Run-Tracker/Views/ActiveRunView.swift)
  - Add `.onDisappear` handler to the idle view that calls `viewModel.stopIdleLocation()` when the view disappears (tab switch or navigation push)
  - The existing `onAppear` already calls `initializeLocation()`, so returning to the idle view restarts tracking
  - Guard: do NOT stop location if a run is active/paused (background tracking must continue)
- **File:** [ActiveRunVM.swift](Run-Tracker/Run-Tracker/ViewModels/ActiveRunVM.swift)
  - Expose a method like `pauseIdleLocationIfNotRunning()` that only stops tracking when `runState == .idle`
  - `stopIdleLocation()` already exists but may need adjustment to be safe to call from `onDisappear`
  - On run completion (`stopRun()`), after saving the run, call `locationProvider.stopTracking()` — location will restart if/when user returns to idle view
- **File:** [Run_TrackerApp.swift](Run-Tracker/Run-Tracker/App/Run_TrackerApp.swift)
  - Consider tracking the selected tab index and stopping location when leaving the Run tab (only if run is idle)
  - Alternative: rely on ActiveRunView's `onAppear`/`onDisappear` lifecycle, which SwiftUI manages per-tab

---

## Phase 8: Elevation Chart Full Width

### 8A. Chart spans actual run distance
- **File:** [ElevationProfileChart.swift](Run-Tracker/Run-Tracker/Views/Components/ElevationProfileChart.swift)
  - Add `totalDistanceMeters: Double` parameter
  - Add explicit `.chartXScale(domain: 0...maxDistanceConverted)` so the X-axis always covers the full run distance
  - Wrap `Chart` in `ScrollView(.horizontal)` with calculated width: `max(containerWidth, distanceUnits * pointsPerUnit)` so short runs fill the screen and long runs scroll
  - Use `GeometryReader` to get container width for the minimum
- **File:** [RunSummaryView.swift](Run-Tracker/Run-Tracker/Views/RunSummaryView.swift)
  - Pass `run.distanceMeters` to `ElevationProfileChart`

---

## Implementation Order

```
Phase 1 (quick fixes)      → no dependencies, do first
Phase 2 (walk metrics)     → depends on Phase 1C (rename)
Phase 3 (split table)      → independent
Phase 4 (map zoom)         → independent
Phase 5 (audio config)     → independent
Phase 6 (pace colors)      → new files, most complex
Phase 7 (location lifecycle) → independent, high priority (battery)
Phase 8 (elevation chart)  → independent
```

Phases 1, 3, 4, 5, 7, 8 can be done in parallel. Phase 2 after Phase 1. Phase 6 last (most complex, needs new PaceColor utility).

## New Files
| File | Purpose | Add to pbxproj |
|------|---------|---------------|
| `Models/AudioCueConfig.swift` | Audio cue field enum & storage | Yes |
| `Extensions/PaceColor.swift` | Pace-based color gradient | Yes |

## Model Changes
- `Run.swift`: Add `var timeToFirstWalkSeconds: Double? = nil` (no migration needed, SwiftData handles optional defaults)

## Verification
- Build after each phase: `xcodebuild -project Run-Tracker.xcodeproj -scheme Run-Tracker -sdk iphonesimulator -configuration Debug build`
- Test: `xcodebuild test -project Run-Tracker.xcodeproj -scheme Run-Tracker -destination 'platform=iOS Simulator,name=iPhone 13 mini'`
- Manual verification on simulator: run through a mock run with walking segments, check split labels, audio cue settings, map zoom behavior
