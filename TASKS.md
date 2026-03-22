# Run Tracker — Task List

Each task is a buildable, testable unit of work. Tasks within a phase are ordered by dependency. Claude Code runs the build/test loop after each task.

---

## Phase 1: Foundation (Data + Core Services)

- [x] **1.1 — Project structure setup**
  Create folder structure (Models/, ViewModels/, Services/, Views/, Views/Components/, Extensions/). Remove template `Item.swift` and `ContentView.swift`. Update `Run_TrackerApp.swift` to remove Item references. Build to verify clean compile.

- [x] **1.2 — Data models**
  Create SwiftData `@Model` classes: `Run`, `Split`, `RoutePoint`, `NamedRoute` per PRD spec. Add relationships and indices. Update `ModelContainer` in app entry point. Build to verify.

- [x] **1.3 — Unit system enum + conversions**
  Create `UnitSystem` enum (`.imperial`, `.metric`) with locale-based default. Create `Double` extensions: `asDistance(unit:)`, `asPace(unit:)`, `asElevation(unit:)`. Write unit tests. Run tests.

- [x] **1.4 — Date formatting extensions**
  Create `Date+Formatting.swift` with run date display formatters. Create duration formatter (HH:MM:SS). Write tests. Run tests.

- [x] **1.5 — RunPersistenceService**
  Create CRUD service for `Run`, `Split`, `RoutePoint`, `NamedRoute` using SwiftData `ModelContext`. Write tests with in-memory container. Run tests.

- [x] **1.6 — ElevationFilter**
  Create moving-average filter (5-sample buffer). Implement gain/loss calculation with ±0.5m dead zone. Write tests with known altitude sequences. Run tests.

- [x] **1.7 — GPXExportService**
  Create GPX 1.1 XML generation from a `Run` with route points. Handle pause gaps as separate `<trkseg>`. Write tests validating XML output. Run tests.

---

## Phase 2: Run Engine (Location + Motion + Splits)

- [x] **2.1 — LocationManager service**
  Define a `LocationProviding` protocol (`startTracking()`, `stopTracking()`, `pauseTracking()`, `resumeTracking()`, published `CLLocation?` and `CLAuthorizationStatus`) so ActiveRunVM can use a mock in tests. Create `LocationManager` class conforming to `LocationProviding` that wraps `CLLocationManager`. On start: `desiredAccuracy = kCLLocationAccuracyBest`, `distanceFilter = kCLDistanceFilterNone`, `allowsBackgroundLocationUpdates = true`, `activityType = .fitness`. On pause: set `desiredAccuracy = kCLLocationAccuracyReduced` and stop delivering updates. On resume: restore best accuracy. Add `NSLocationWhenInUseUsageDescription` to Info.plist. Add background location capability to entitlements. Build to verify.

- [x] **2.2 — MotionManager service**
  Define a `MotionProviding` protocol (`startCadenceUpdates(from:)`, `stopCadenceUpdates()`, published cadence `Double?` and step count `Int`) so ActiveRunVM can use a mock in tests. Create `MotionManager` class conforming to `MotionProviding` that wraps `CMPedometer`. Publish `currentCadence` × 60 for spm and `numberOfSteps`. Check `CMPedometer.isStepCountingAvailable()`. Add `NSMotionUsageDescription` to Info.plist. Build to verify.

- [x] **2.3 — SplitTracker**
  Create split detection logic: maintain `nextSplitBoundary` (1609.344m for imperial, 1000m for metric). When cumulative distance crosses the boundary, snapshot delta stats (distance, duration, elevation gain/loss, cadence) and fire a split event via a Combine publisher or callback. Accept `UnitSystem` to determine boundary distance. Add `isPartial: Bool` property to the `Split` model for the final partial segment. Write tests with simulated distance sequences covering: single split, multiple splits, partial final split, unit system switching. Run tests.

- [x] **2.4 — ActiveRunVM — state machine**
  Create `@Observable` view model with `RunState` enum (`.idle`, `.active`, `.paused`). Timer via `Combine Timer.publish(every: 1.0)` — only increment `elapsedSeconds` when `.active`. Distance accumulation via `location.distance(from: previousLocation)` for each valid GPS fix. Feed altitude to `ElevationFilter`. Current pace: rolling window of last 15 seconds of RoutePoints, recalculated every 5 seconds; display "— —" if speed < 0.3 m/s. Average pace: `elapsedSeconds / (totalDistanceMeters / metersPerUnit)`. Wire up `LocationProviding`, `MotionProviding`, `SplitTracker`, `ElevationFilter`. Maintain `displayedRouteCoordinates` array (appended every 3s for map polyline). Write tests for state transitions, distance accumulation, pace calculation, and elevation tracking using mock `LocationProviding` and `MotionProviding`. Run tests.

---

## Phase 3: Active Run UI (Map + Stats + Controls)

- [x] **3.1 — StatCard + GPSSignalIndicator components**
  Create reusable `StatCard` view (value + unit label, monospaced font). Create GPS signal indicator (0-3 bars from horizontalAccuracy). Build to verify.

- [x] **3.2 — LongPressButton component**
  Create long-press stop button with circular progress ring (1.5s hold). Haptic feedback on completion. Build to verify.

- [x] **3.3 — ActiveRunView — idle state**
  Create pre-run screen: large green Start button, GPS signal indicator, unit label, background map showing current location. Wire to ActiveRunVM. Build and launch on simulator.

- [x] **3.4 — ActiveRunView — active state**
  Create live stats dashboard (time, distance, elevation, pace, cadence in 2-column grid). Map with polyline (top 55%, stats bottom 45%). Map style toggle. Re-center button with 5s auto-re-engage. Polyline throttled to 3s updates. Build and launch on simulator.

- [x] **3.5 — ActiveRunView — paused state**
  Implement paused UI: pulsing timer, amber tint, "PAUSED" label, Resume/Stop buttons. Wire pause/resume to VM and services. Build and launch on simulator.

- [x] **3.6 — Split toast notification**
  Create slide-down banner showing split time when a split boundary is crossed. Auto-dismiss after 5s. Semi-transparent background. Build to verify.

- [x] **3.7 — Navigation structure**
  Set up `NavigationStack` in `Run_TrackerApp`. Tab bar or root with: Active Run, History, Settings. Wire up navigation. Build and launch on simulator.

---

## Phase 4: Post-Run (Summary + History)

- [x] **4.1 — RunSummaryVM**
  Create view model initialized from a `Run` model. Compute all display values (formatted stats, split data, elevation profile data). Write tests. Run tests.

- [x] **4.2 — ElevationProfileChart**
  Create Swift Charts view: `AreaMark` + `LineMark`, distance on X, elevation on Y. Green-to-brown gradient fill. Build to verify.

- [x] **4.3 — SplitTableView**
  Create split table component: split index, time, pace, elevation, cadence. Fastest split green, slowest red. Partial split italicized. Build to verify.

- [x] **4.4 — RunSummaryView**
  Scrollable layout: header (date/route), stat cards (2x2 grid), route map (fitted polyline, start/finish pins), elevation profile, splits table, action buttons (Name Route, Export GPX, Delete). Wire to RunSummaryVM. Build and launch on simulator.

- [x] **4.5 — RunHistoryVM**
  Create view model with SwiftData queries. Support sort by date/distance/duration/pace. Support filter by date range, min distance, named route. Write tests with in-memory data. Run tests.

- [x] **4.6 — RunHistoryListView**
  Create history list with run row cards (date, distance, duration, pace, route name). Sort/filter sheet. Swipe-to-delete with confirmation. Empty state. NavigationLink to RunSummaryView. Build and launch on simulator.

---

## Phase 5: Polish Features

- [x] **5.1 — AudioCueService**
  Create AVSpeechSynthesizer service. Subscribe to split events and time intervals. Audio session with `.duckOthers`. Configurable: on/off, at splits, at time intervals (1/5/10 min). Build to verify.

- [x] **5.2 — SettingsVM + SettingsView**
  Create settings screen: unit preference (segmented), audio cues (toggle + sub-options), appearance (System/Light/Dark), offline maps section (cache size, clear cache). Wire to `@AppStorage`. Build and launch on simulator.

- [x] **5.3 — Named routes — assignment and management**
  Create route name assignment sheet (from RunSummaryView): text field + existing route picker. Create RouteDetailView: route stats (best time/pace, run count), runs list, pace trend chart. Rename/delete route. Build and launch on simulator.

- [x] **5.4 — GPX export integration**
  Wire GPXExportService to RunSummaryView "Export GPX" button. Use `ShareLink` for system share sheet. Filename format: `RunTracker_YYYY-MM-DD_HHMMSS.gpx`. Build to verify.

- [x] **5.5 — Dark mode**
  Implement appearance override via `@AppStorage` + `.preferredColorScheme()`. True black backgrounds (`#000000`). High-contrast text/accent colors. Map style switches to muted in dark mode. Verify no white flashes. Build and launch on simulator.

- [x] **5.6 — Offline map support**
  Create MapTileCacheService with custom `URLCache` (500MB disk). Implement "Download Map Area" flow (enumerate tiles at zoom 10-16, prefetch). Display cache size in settings. Clear cache option. Offline badge on map. Build to verify.

---

## Phase 6: Integration & Edge Cases (DEFERRED)

> Deferred to a future release. See PRD v1 for details.

- [ ] **6.1 — GPS edge cases**
- [ ] **6.2 — Zero-distance run handling**
- [ ] **6.3 — Permission flows**
- [ ] **6.4 — Battery optimization audit**
- [ ] **6.5 — Info.plist and capabilities**
- [ ] **6.6 — Final integration test**

---

## Phase 7: Bug Fixes (PRD v2)

- [x] **7.1 — Stop button: remove long press**
  Replace `LongPressButton` with a standard tap button + confirmation alert ("End this run?" with End Run / Cancel). Move haptic feedback to confirmation. Update `ActiveRunView` active and paused states. Build and launch on simulator.

- [x] **7.2 — Larger stop/pause buttons**
  Increase stop and pause/resume button tap targets to at least 64×64 pt (ideally 72 pt). Use bold iconography with high-contrast colors. Ensure buttons are easy to hit one-handed while fatigued. Update layout in `ActiveRunView`. Build and launch on simulator.

- [x] **7.3 — Fix completed runs not appearing in history**
  Debug `stopRun()` flow in `ActiveRunVM` — verify `RunPersistenceService.save()` is called and `ModelContext` is committed. Verify `Run.endDate` is set. Verify `RunHistoryVM` re-queries SwiftData on changes. Write a test that creates and saves a run, then verifies it appears in history queries. Run tests. Build and launch on simulator.

- [x] **7.4 — Fix audio cues not firing**
  Debug `AudioCueService` timer subscription — verify it connects to `ActiveRunVM` state and fires at configured intervals. Verify `AVAudioSession` is set to `.playback` with `.duckOthers` and is activated before speaking. Verify `AVSpeechSynthesizer` instance is retained during the run. Add last split pace to spoken cue text. Test that cues work when app is backgrounded. Update spoken cue format: "Ten minutes. One point five miles. Average pace: eight twelve per mile. Last split: seven fifty-eight per mile." Build and launch on simulator.

---

## Phase 8: UI Improvements (PRD v2)

- [x] **8.1 — Settings: configurable split distance**
  Add `SplitDistance` enum with options: quarter (402.336m / 250m), half (804.672m / 500m), full (1609.344m / 1000m) based on unit system. Add split distance picker to `SettingsView` below unit selector — picker options update when unit system changes. Persist via `@AppStorage`. Update `SplitTracker` to accept configurable split distance. Update split toast and split table headers to reflect chosen distance. Write tests for `SplitTracker` with different split distances. Run tests. Build and launch on simulator.

- [x] **8.2 — App icon**
  Design and add app icon: running silhouette or abstract figure on dark background with accent green (`#30D158`). Generate all required sizes from 1024×1024 source. Add to `Assets.xcassets/AppIcon.appiconset`. Build and verify icon appears on simulator home screen.

- [x] **8.3 — Live map: center on runner with adjustable zoom**
  For new (non-named) routes, keep map centered on runner's position during active run. Allow pinch-to-zoom without losing centering. Add +/- zoom buttons as overlay. Persist preferred zoom level via `@AppStorage`. Build and launch on simulator.

- [x] **8.4 — Named route: toggle runner view vs route view**
  When running a named route, add a toggle button on the map to switch between: (1) Runner view — centered on current position with user's zoom level, and (2) Route view — zoomed out to show full named route overlay with runner position marked. Named route overlay drawn as dashed gray polyline. Animate camera transitions between modes. Build and launch on simulator.

- [x] **8.5 — Offline maps: restrict to named routes only**
  Remove the manual "Download Map Area" flow from settings. Auto-cache map tiles for named route regions (bounding box, zoom 10–16) when a run is assigned to a route. Keep cache size display and "Clear Cache" in settings. Simplify `MapTileCacheService` API to `cacheRoute(_:)`. Build and launch on simulator.

---

## Phase 9: Route Overlay & Elevation Features (PRD v2)

- [x] **9.1 — Named route overlay with timing benchmarks**
  When running a named route, display the benchmark run's GPS trail as a reference overlay (3 pt dashed, semi-transparent). Add split point markers along the route showing benchmark split times. Add `benchmarkRunID` to `NamedRoute` model. Create `RouteComparisonVM` to compute current vs benchmark deltas. Build and launch on simulator.

- [x] **9.2 — Ahead/behind pace indicator**
  Show a live ahead/behind time indicator comparing current split times to the benchmark run. Display as "+0:23" (red, behind) or "-0:15" (green, ahead) near the timer. Update at each split boundary. Wire to `RouteComparisonVM`. Build and launch on simulator.

- [x] **9.3 — Elevation-colored polyline on live map**
  Color-code the active run polyline by elevation: green (low) → yellow → orange → brown (high), relative to current run's min/max elevation. Segment route into groups of ~5 points, compute average altitude, map to gradient color. Add a small elevation legend/gradient bar on the map. Update every 3 seconds. Write tests for color mapping logic. Run tests. Build and launch on simulator.

- [x] **9.4 — Time markers on map**
  Drop time markers on the map at configurable intervals (default 5 min). Each marker shows elapsed time (e.g., "10:00"). Add `timeMarkerInterval` setting to `SettingsVM` (options: 1, 2, 5, 10 min). Maintain `timeMarkers` array in `ActiveRunVM`. Render as `Annotation` views. Show markers on both live map and run summary map. Build and launch on simulator.

---

## Phase 10: Quick Fixes (PRD v3)

- [x] **10.1 — App icon redesign**
  Replace the current app icon with a clean, minimal design: green (#30D158) on black. Use a simple geometric shape (bold chevron/arrow suggesting forward motion, or abstract route line). Flat design, no gradients. Generate 1024×1024 source and all required sizes. Replace contents of `Assets.xcassets/AppIcon.appiconset`. Build and verify icon on simulator.

- [x] **10.2 — Split audio cues: correct split label for split distance**
  Update `AudioCueService.handleSplit()` to use the current `SplitDistance` setting for the spoken label. Quarter splits say "Quarter mile 1" / "Quarter K 1", half splits say "Half mile 1" / "Half K 1", full splits say "Mile 1" / "Kilometer 1". Pace remains normalized to per-mile or per-km regardless of split distance. Pass `SplitDistance` to `AudioCueService` or read it from the split snapshot. Write tests for the label formatting. Run tests. Build to verify.

- [x] **10.3 — Restyle RunSummaryView action buttons**
  Redesign the action buttons section in `RunSummaryView`. Replace the oversized `.bordered` HStack with a compact icon-circle layout: three circular buttons (44 pt) with SF Symbols and small caption labels underneath (Name Route, Export, Delete). Use `.font(.caption)` for labels. Keep delete confirmation alert. Build and launch on simulator.

---

## Phase 11: Route Selection at Run Start (PRD v3)

- [x] **11.1 — Route selection sheet**
  Create a `RouteSelectionSheet` view that appears when the user taps Start (only if named routes exist). Show "Free Run" as the top option with a running figure icon, then a "Your Routes" section listing named routes with name and run count. Query named routes from SwiftData. Add a "Cancel" button. Present as `.presentationDetents([.medium])`. Build to verify.

- [x] **11.2 — Wire route selection to run start**
  In `ActiveRunView`, add state for `showRouteSelection` and `selectedRoute`. When Start is tapped: if named routes exist, show `RouteSelectionSheet`; otherwise start immediately. On route selection, call `viewModel.setNamedRoute(route)` then `viewModel.startRun()`. On "Free Run", call `viewModel.startRun()` directly. Add `selectedNamedRoute` property to `ActiveRunVM`. Build and launch on simulator.

- [x] **11.3 — Auto-assign route on run completion**
  When a run completes and `ActiveRunVM.selectedNamedRoute` is set, auto-assign the run to that route (same as `RunPersistenceService.assignRoute()`). Skip the manual route assignment step. Show the route name on the active run screen (small label near the top). Update `stopRun()` to store the selected route on the `Run` before saving. Write tests. Run tests. Build and launch on simulator.

---

## Phase 12: Named Route Detail View Overhaul (PRD v3)

- [x] **12.1 — Route map with path overlay**
  Redesign `RouteDetailView` to be map-centric. Add a `Map` view taking ~60% of the screen showing the route's GPS trail as a solid green polyline (3-4 pt). Use the benchmark run's (or best run's) route points. Fit the map to the route's bounding box with padding. Keep the header with route name, run count. Build and launch on simulator.

- [x] **12.2 — Split markers on route map**
  Add split boundary markers to the route map in `RouteDetailView`. Compute split locations from the benchmark run's route points (find the coordinate where cumulative distance crosses each split boundary). Show as small circular pins with distance labels ("Mi 1", "Mi 2" or "Km 1", "Km 2"). Show the benchmark split time in a small callout. Build and launch on simulator.

- [x] **12.3 — Timing info and stats section**
  Add a stats section below the map: best time, average time, last run time. Show a split table with the benchmark run's split times and paces (reuse `SplitTableView`). Keep the existing pace trend chart and run list below. Preserve rename/delete actions. Build and launch on simulator.

---

## Phase 13: Coach Mode (PRD v3)

- [x] **13.1 — Coach data computation**
  Extend `RouteComparisonVM` (or create a `CoachService`) to compute: (1) `lastRunCumulativeSplitTimes` — cumulative times at each split from the most recent run on the route, (2) `averageCumulativeSplitTimes` — average cumulative times across all runs on the route. Write tests with mock split data covering: normal case, runs with different split counts, single run (last = average). Run tests.

- [x] **13.2 — Coach mode toggle and state**
  Add `isCoachModeEnabled: Bool` to `ActiveRunVM`. Add a coach mode toggle to `RouteSelectionSheet` (visible when a route is selected, hidden for free run). Add `@AppStorage("coachModeDefault")` to remember the preference. Add a small "Coach" badge/button on the active run stats dashboard that toggles coach mode on/off. Green when active, dimmed when off. Only visible when running a named route with prior runs. Build and launch on simulator.

- [x] **13.3 — Coach mode audio cues**
  Update `AudioCueService.handleSplit()`: when coach mode is active, append comparison text. Compare current cumulative time at split N to last run and average. Speak: "X seconds ahead of your last run. Y seconds ahead of your average." (or "behind"). Handle cases where current run has more splits than comparison data (stop comparing gracefully). Pass coach data and enabled flag from `ActiveRunVM` to `AudioCueService`. Write tests for the comparison text formatting. Run tests. Build to verify.

- [x] **13.4 — Coach mode split toast**
  Update `SplitToastView` to show comparison deltas when coach mode is active. Display "+0:12" (red, behind) or "-0:05" (green, ahead) vs last run below the split time. Pass comparison data to `SplitToastView`. Build and launch on simulator.

---

## Phase 14: Landing Page & Background Running (PRD v4)

- [x] **14.1 — Landing page: tighter map zoom**
  Set the idle map to a street-level zoom (`MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)`) centered on the user's location using `.camera(MapCamera(...))` or a computed region. Replace the default `.userLocation(fallback: .automatic)` with an explicit tight region once user location is available. Build and launch on simulator.

- [x] **14.2 — Landing page: remove mi/km label**
  Remove the `Text(unitSystem == .imperial ? "miles" : "km")` label from the idle view in `ActiveRunView`. Build and launch on simulator.

- [x] **14.3 — Landing page: last run summary card**
  Add a compact last-run summary below the Start button on the idle screen. Query the most recent `Run` from SwiftData. Show date, distance, and pace in a small capsule/card. If no runs exist, show nothing. Build and launch on simulator.

- [x] **14.4 — Background running: location indicator**
  Set `showsBackgroundLocationIndicator = true` on `CLLocationManager` in `LocationManager.startTracking()`. This displays the blue status bar pill during background tracking. Build to verify.

- [x] **14.5 — Background running: Always authorization**
  Change `LocationManager.startTracking()` to call `requestAlwaysAuthorization()` instead of `requestWhenInUseAuthorization()`. Add `NSLocationAlwaysAndWhenInUseUsageDescription` to Info.plist with message: "Run Tracker needs location access to track your runs even when the screen is locked." Keep `NSLocationWhenInUseUsageDescription` as a fallback. Build to verify.

- [x] **14.6 — Background running: keep audio session active**
  In `AudioCueService`, stop deactivating the audio session after each utterance when a run is active. Add an `isRunActive: Bool` property. When true, keep the session active in `speechSynthesizer(_:didFinish:)` instead of calling `deactivateAudioSession()`. Set `isRunActive = true` in `startListening()` and `false` in `stopListening()`. Build to verify.

- [x] **14.7 — Background running: idle timer & background task**
  In `ActiveRunVM.startRun()`, set `UIApplication.shared.isIdleTimerDisabled = true`. In `stopRun()`, set it back to `false`. Add `UIBackgroundModes: audio` to Info.plist alongside the existing `location` mode. Build to verify.

- [x] **14.8 — Background running: verify timer continuity**
  Verify the Combine `Timer.publish(every:on:in:)` uses `.common` run loop mode. If the timer in `ActiveRunVM` or `AudioCueService` uses `.default` mode, switch to `.common`. Write a note in the code explaining that `.common` mode is required for background execution. Build to verify.

---

## Phase 15: Weather Data Capture (PRD v4)

- [x] **15.1 — Weather data model fields**
  Add weather properties to the `Run` model: `temperatureCelsius: Double?`, `feelsLikeCelsius: Double?`, `humidityPercent: Double?`, `windSpeedMPS: Double?`, `weatherCondition: String?`, `weatherConditionSymbol: String?`. Build to verify migration compiles.

- [x] **15.2 — WeatherService**
  Create a `WeatherService` using Apple WeatherKit (`import WeatherKit`). Method: `func fetchCurrentWeather(for location: CLLocation) async -> WeatherSnapshot?` returning a simple struct with temperature, feels-like, humidity, wind speed, condition name, and SF Symbol. Handle errors gracefully (return nil). Add WeatherKit capability to entitlements. Write tests with mock data. Run tests.

- [x] **15.3 — Capture weather at run start**
  In `ActiveRunVM.startRun()`, call `WeatherService.fetchCurrentWeather()` with the current location. Store the result. In `stopRun()`, write weather fields to the `Run` model before saving. If weather fetch fails, leave fields nil. Build to verify.

- [x] **15.4 — Display weather on RunSummaryView**
  Add a weather section to `RunSummaryView` below the stat cards. Show: condition icon (SF Symbol), temperature, feels-like, humidity, wind. Use the user's unit system (°F/°C, mph/km/h). If weather data is nil, hide the section. Show time-of-day label in the header. Build and launch on simulator.

- [x] **15.5 — Weather icon on history list**
  Add a small weather condition SF Symbol icon to each run row in `RunHistoryListView`. If the run has no weather data, show nothing. Build and launch on simulator.

---

## Phase 16: Run Import (PRD v4)

- [x] **16.1 — GPXImportService**
  Create `GPXImportService` using `XMLParser` to parse GPX 1.1 files. Extract `<trkpt>` elements (lat, lon, ele, time) grouped by `<trkseg>`. Return an array of parsed track segments. Handle malformed files with clear error messages. Write tests with sample GPX strings. Run tests.

- [x] **16.2 — Import: compute run stats from GPX**
  Extend `GPXImportService` with a method that takes parsed track points and computes: total distance, duration, elevation gain/loss, average pace, splits (using `SplitTracker` logic). Return a preview struct with all computed stats plus the route coordinates. Write tests. Run tests.

- [x] **16.3 — Import preview screen**
  Create `GPXImportPreviewView` showing: date, distance, duration, pace, elevation, route map with polyline. Add "Import" and "Cancel" buttons. On import, save the Run with all computed stats, splits, and route points using `RunPersistenceService`. Build and launch on simulator.

- [x] **16.4 — Import entry point**
  Add an "Import" toolbar button (SF Symbol: `square.and.arrow.down`) to `RunHistoryListView`. Use `.fileImporter(isPresented:allowedContentTypes:)` with `[.xml]` (GPX is XML-based). On file selection, parse and navigate to the preview screen. Register GPX UTType in Info.plist. Build and launch on simulator.

- [x] **16.5 — Bulk export**
  Add "Export All Runs" option in `SettingsView`. Generate one GPX file per run, bundle into a temporary directory, and share via `ShareLink`. Or export a single multi-track GPX file. Build and launch on simulator.

---

## Phase 17: Bug Fixes (Post-PRD v4)

- [x] **17.1 — Fix audio cues not playing with screen off**
  Audio cues (split and time-interval) do not fire when the screen is locked during a run. The split trigger is distance-based (accumulated in `ActiveRunVM` via location updates) and the time trigger runs on the Combine timer — both should continue in background if location and audio background modes are active. Investigate and fix:
  1. Verify `AVAudioSession` category is `.playback` (not `.ambient`) and is activated before the first cue — `.ambient` is silenced by the silent switch and does not play in background.
  2. Verify the audio session is not being deactivated between cues while a run is active — check `AudioCueService.isRunActive` is set correctly and `speechSynthesizer(_:didFinish:)` does not call `deactivateAudioSession()` during an active run.
  3. Verify `AVSpeechSynthesizer` is retained for the life of the run (not recreated per cue) — a deallocated synthesizer will silently drop utterances.
  4. Verify `UIBackgroundModes` in Info.plist contains both `audio` and `location`.
  5. Check that `AudioCueService.startListening()` re-subscribes to the split publisher correctly on resume (the publisher may complete if `splitTracker` is recreated on `startRun()`).
  6. Add a `beginBackgroundTask` in `AudioCueService` around each utterance to give the app extra time to complete speech before being suspended.
  Test on a real device with screen locked. Build to verify.

---

## Phase 18: App Store Prep — Assets & Launch Screen

- [x] **18.1 — App icon audit**
  Verify `Assets.xcassets/AppIcon.appiconset/AppIcon.png` is exactly 1024×1024, PNG format, no alpha channel, no transparency. If alpha is present, flatten it onto a black background. Rebuild and verify the icon renders on the simulator home screen. Ensure `Contents.json` has the correct single-size entry for Xcode 15+ automatic generation.

- [x] **18.2 — Launch screen**
  Create a launch screen using the `UILaunchScreen` Info.plist key. Set a background color matching the app's system background (supports dark mode). Optionally add the app icon image centered. Add the key to Info.plist (or project build settings). Build and verify on simulator — confirm no white flash on launch in both light and dark mode.

- [x] **18.3 — Remove unused background mode**
  Audit `UIBackgroundModes` in Info.plist. The `remote-notification` mode is declared but the app does not use push notifications. Remove it to avoid App Review questions. Verify `audio` and `location` modes remain. Build to verify.

- [x] **18.4 — Version and build number**
  Set `MARKETING_VERSION` to `1.0.0` and `CURRENT_PROJECT_VERSION` to `1` in the project build settings (both Debug and Release). Verify they appear correctly in the built app's Info.plist. Build to verify.

---

## Phase 19: App Store Prep — Metadata & Screenshots

- [x] **19.1 — App Store Connect metadata file**
  Create `fastlane/metadata/en-US/` directory structure (or a `metadata.json` reference file) containing all App Store Connect text fields: app name ("FreePace"), subtitle ("GPS Running & Route Recorder"), description (full marketing copy from APP-STORE-PRD.md §4), keywords ("running,gps,tracker,pace,cadence,splits,route,map,fitness,run"), promotional text, SKU ("freepace-ios-v1"), primary category (Health & Fitness), secondary category (Sports). This serves as the source of truth for copy — paste into App Store Connect at submission time.

- [x] **19.2 — Screenshot capture plan**
  Document a screenshot capture script or manual steps. Minimum: 6 screenshots for iPhone 6.9" (1320×2868) and iPhone 6.3" (1206×2622). Screens: (1) Active run with live map, (2) Run summary, (3) Splits view, (4) Run history list, (5) Audio cues / settings, (6) Offline maps or route detail. Populate the simulator with realistic test data (several runs with varied distances, named routes, weather data) before capturing.

- [ ] **19.3 — Capture screenshots** *(manual — requires running the app on simulator with test data, see SCREENSHOT-PLAN.md)*
  Using the simulator (iPhone 16 Pro Max for 6.9", iPhone 16 Pro for 6.3"), capture all 6 screenshots in both light and dark mode. Save to `screenshots/` directory organized by device. Ensure screenshots use real-looking data — not empty states or default placeholder content.

---

## Phase 20: App Store Prep — Privacy, Legal & Submission

- [x] **20.1 — Privacy policy**
  Write a privacy policy page covering: precise location data collection for run tracking, motion/fitness data for cadence, all data stored locally on device only, no data transmitted to external servers, no user accounts, no third-party analytics or advertising SDKs, no data sharing. Host at a publicly accessible URL (GitHub Pages, simple static site, or similar). Record the URL. *(Content created in PRIVACY-POLICY.md — hosting at a public URL is a manual step.)*

- [x] **20.2 — Support page**
  Create a support page with: app name, brief description, contact email for support, FAQ covering common questions (location permissions, battery usage, data export). Host at a publicly accessible URL. Record the URL. *(Content created in SUPPORT.md — hosting at a public URL is a manual step.)*

- [x] **20.3 — App Privacy declarations**
  Document the App Store Connect App Privacy answers: (1) Precise Location — collected, not linked to user, not used for tracking, used for App Functionality only. (2) Fitness & Exercise (cadence/steps) — collected, not linked to user, not used for tracking, used for App Functionality only. (3) All other categories — not collected. *(Documented in APP-PRIVACY-DECLARATIONS.md.)*

- [x] **20.4 — Age rating & pricing**
  Document App Store Connect age rating questionnaire answers (all "None" — expected rating 4+). Pricing: Free, no in-app purchases, no subscriptions. Availability: all territories. Release type: manual release after approval. *(Documented in AGE-RATING-AND-PRICING.md.)*

- [ ] **20.5 — WeatherKit capability verification** *(manual — requires Apple Developer portal access)*
  Verify the Apple Developer portal has WeatherKit capability enabled for bundle ID `sawtoothdata.FreeRun`. Verify the entitlements file includes `com.apple.developer.weatherkit`. Ensure the provisioning profile includes this capability for distribution.

- [ ] **20.6 — Pre-submission build verification** *(manual — requires physical device and Xcode archive)*
  Archive the app with Release configuration. Validate the archive in Xcode (Product → Validate App). Fix any validation errors: missing icons, missing usage descriptions, invalid entitlements, etc. Run on a physical device to verify: location permissions flow, motion permissions flow, background tracking, audio cues, GPX export, dark mode. Confirm no compiler warnings in Release build.

---

## Phase 21: Landing Page Map Centering (PRD5 §2)

- [x] **21.1 — Measure idle overlay panel height**
  In `ActiveRunView.swift`, wrap the bottom VStack (GPS signal indicator + Start button + last-run card) in a `GeometryReader` or attach a `.onGeometryChange(of:)` modifier to read its height. Store the measured height in a local `@State var overlayPanelHeight: CGFloat = 220` (220 pt is the safe fallback before measurement). Pass the value up to the idle camera offset computation introduced in 21.2. The map content itself must not be resized — only the height value is captured. Build to verify the idle screen still renders correctly.
  **Files:** `ActiveRunView.swift`

- [x] **21.2 — Offset idle map camera to center user dot in visible area**
  In `ActiveRunView.swift`, add a computed property `idleCameraCenter: CLLocationCoordinate2D` that shifts the user's true coordinate south by half the overlay panel height, expressed in degrees of latitude. Compute: `degreesPerPoint = 0.005 / screenHeight` (where `screenHeight` comes from a `GeometryReader` wrapping the whole view, and `0.005` is the fixed `latitudeDelta` set in task 14.1); `latitudeOffset = (overlayPanelHeight / 2) * degreesPerPoint`; return `CLLocationCoordinate2D(latitude: userLatitude - latitudeOffset, longitude: userLongitude)`. Replace the existing idle `MapCamera` center coordinate with `idleCameraCenter`. Recalculate whenever `userLocation`, `overlayPanelHeight`, or `screenHeight` changes. Guard this offset behind `runState == .idle` so the active-run map is unaffected. Write a unit test for the offset formula given a known `latitudeDelta`, `screenHeight`, and `overlayPanelHeight`. Run tests. Build and launch on simulator; verify on iPhone SE (small), iPhone 16 (standard), and iPhone 16 Pro Max (large) using different simulator sizes.
  **Files:** `ActiveRunView.swift`, `ActiveRunVMTests.swift` (or a new `MapOffsetTests.swift`)

---

## Phase 22: Pre-Run Countdown (PRD5 §3)

- [x] **22.1 — Add `.countdown` case to RunState and countdown logic to ActiveRunVM**
  Add `case countdown` to the `RunState` enum in `ActiveRunVM.swift`. The state machine flow becomes `.idle → .countdown → .active`. Add properties: `countdownSeconds: Int = 10` and a private `var countdownCancellable: AnyCancellable?`. Add `startCountdown()`: transition `runState = .countdown`, call `locationManager.startTracking()` (to begin GPS acquisition), reset `countdownSeconds = 10`, subscribe a 1-second `Timer.publish(every: 1.0, on: .main, in: .common)` that decrements `countdownSeconds` and fires `UIImpactFeedbackGenerator(style: .light).impactOccurred()` on each tick; when `countdownSeconds` reaches 0, call `startRunNow()`. Add `startRunNow()`: cancel the countdown timer, then perform the full run-start sequence that was previously in `startRun()` (start elapsed timer, motion tracking, split tracking, audio cues, idle-timer disable, weather fetch) and set `runState = .active`. Rename the existing `startRun()` to `startRunNow()` and update `startRun()` to call `startCountdown()`. Add `cancelCountdown()`: cancel the countdown timer, call `locationManager.stopTracking()`, set `runState = .idle`, reset `countdownSeconds = 10`. The countdown state must NOT be persisted — if the app restarts during countdown it returns to `.idle`. Write tests for state transitions (`.idle → .countdown`, `.countdown → .active` via `startRunNow()`, `.countdown → .idle` via `cancelCountdown()`), verifying that `elapsedSeconds` remains 0 and `totalDistanceMeters` remains 0 throughout the countdown. Run tests.
  **Files:** `ActiveRunVM.swift`, `ActiveRunVMTests.swift`

- [x] **22.2 — Wire Start button and RouteSelectionSheet to startCountdown()**
  In `ActiveRunView.swift`, find all call sites of `viewModel.startRun()` — the direct Start-button tap path and the confirmation path inside the `RouteSelectionSheet` (both the "Free Run" selection and the named-route selection). Replace each call with `viewModel.startCountdown()`. Verify that `viewModel.setNamedRoute(_:)` is still called before `startCountdown()` when a named route is selected, so the route is stored on the VM before the countdown begins. Build and launch on simulator; confirm that tapping Start triggers a countdown rather than immediately beginning the run.
  **Files:** `ActiveRunView.swift`, `RouteSelectionSheet.swift`

- [x] **22.3 — Countdown UI overlay in ActiveRunView**
  In `ActiveRunView.swift`, add a `.countdown` branch in the top-level state switch (alongside the existing `.idle`, `.active`, `.paused` branches). The countdown screen reuses the active-run map as the background (same `Map` view with polyline, same top-inset layout). Over the map, center a `VStack` containing: (1) a `Text("\(viewModel.countdownSeconds)")` styled `.font(.system(size: 96, weight: .bold, design: .monospaced))` with a `scaleEffect` animation that pulses from 1.2 to 1.0 over 0.8 s on each tick (trigger via `id: viewModel.countdownSeconds` on a `.animation(.easeOut(duration: 0.8), value: viewModel.countdownSeconds)`); (2) a `Text("Tap to skip")` in `.subheadline` / `.secondary` color. Attach a `.onTapGesture { viewModel.startRunNow() }` to the full-screen overlay so tapping anywhere on the number or hint skips the countdown. At the bottom of the screen, show a single "Cancel" button (`.bordered` style, 64×44 minimum tap target) that calls `viewModel.cancelCountdown()`. No Pause or Stop buttons appear during countdown. Build and launch on simulator; verify the digit pulses on each tick, the skip tap works, and Cancel returns to the idle screen.
  **Files:** `ActiveRunView.swift`

---

## Phase 23: Cool Down Phase — data model + engine (PRD5 §4, backend only)

- [x] **23.1 — Add `isCoolDown` to Split model and SplitSnapshot**
  In `Split.swift`, add `var isCoolDown: Bool = false` as a stored property on the `@Model` class. The SwiftData default value of `false` means no migration is needed for existing runs — they are treated as running splits. In `ActiveRunVM.swift`, find the `SplitSnapshot` struct (which captures per-split metrics when a boundary is crossed) and add `var isCoolDown: Bool`. In `stopRun()`, when iterating over stored `SplitSnapshot` values to build `Split` model objects, set `split.isCoolDown = snapshot.isCoolDown`. Write unit tests that create a `Split` with `isCoolDown = true` in an in-memory SwiftData container, save it, and verify the value round-trips correctly. Run tests. Build to verify.
  **Files:** `Split.swift`, `ActiveRunVM.swift`, `SplitTests.swift` (or `RunPersistenceServiceTests.swift`)

- [x] **23.2 — Add cool-down aggregate fields to Run model**
  In `Run.swift`, add three stored properties to the `@Model` class: `var hasCoolDown: Bool = false`, `var coolDownDistanceMeters: Double = 0`, `var coolDownDurationSeconds: Double = 0`. Default values of `false` / `0` ensure no migration is needed for existing runs. Build to verify.
  **Files:** `Run.swift`

- [x] **23.3 — Add isCoolDownActive toggle and accumulators to ActiveRunVM**
  In `ActiveRunVM.swift`, add `var isCoolDownActive: Bool = false` (published). Add `private var coolDownDistanceAccumMeters: Double = 0` and `private var coolDownDurationAccumSeconds: Double = 0` and `private var hadCoolDownDuringRun: Bool = false`. Add `toggleCoolDown()`: flip `isCoolDownActive`; if `runState == .active || runState == .paused`, set `hadCoolDownDuringRun = true` when toggling on. In the per-second timer handler (when `.active`), if `isCoolDownActive` is true, also increment `coolDownDurationAccumSeconds`. In the per-location-update handler where distance is accumulated, if `isCoolDownActive` is true, also add the delta to `coolDownDistanceAccumMeters`. When `SplitTracker` fires a split boundary and the `SplitSnapshot` is created, set `snapshot.isCoolDown = isCoolDownActive`. In `stopRun()`, before saving the `Run`, set: `run.hasCoolDown = hadCoolDownDuringRun`, `run.coolDownDistanceMeters = coolDownDistanceAccumMeters`, `run.coolDownDurationSeconds = coolDownDurationAccumSeconds`. In `startRun()` / `startRunNow()`, reset all three accumulators to `0` and `hadCoolDownDuringRun = false` and `isCoolDownActive = false`. Add computed properties: `var runningOnlyDistanceMeters: Double { totalDistanceMeters - coolDownDistanceAccumMeters }` and `var runningOnlyDurationSeconds: Double { elapsedSeconds - coolDownDurationAccumSeconds }`. Write tests: (a) toggle cool-down on, simulate location updates and timer ticks, toggle off, verify accumulators; (b) verify split snapshots are tagged correctly; (c) verify `stopRun()` populates `Run` fields; (d) verify reset on new run. Run tests.
  **Files:** `ActiveRunVM.swift`, `ActiveRunVMTests.swift`

- [x] **23.4 — AudioCueService: cool-down prefix and mode-transition cues**
  In `AudioCueService.swift`, add a `var isCoolDownActive: Bool = false` property. In the time-interval cue handler (the method that speaks "Ten minutes. One point five miles…"), prepend `"Cool down — "` to the utterance string when `isCoolDownActive == true`. In `ActiveRunVM.toggleCoolDown()`, after flipping `isCoolDownActive`, update `audioService.isCoolDownActive` and, if audio cues are globally enabled and `runState == .active`, enqueue a one-shot `AVSpeechUtterance`: "Cool down started." when turning on, "Running resumed." when turning off. Split-boundary cues (spoken split time) are also prefixed with "Cool down — " when `isCoolDownActive`. Write tests for the spoken string construction in both modes. Run tests. Build to verify.
  **Files:** `AudioCueService.swift`, `ActiveRunVM.swift`, `AudioCueServiceTests.swift`

---

## Phase 24: Cool Down Phase — UI (PRD5 §4, UI layer)

- [x] **24.1 — Cool Down toggle button in active-run control bar**
  In `ActiveRunView.swift`, in the bottom control strip that currently shows the Pause button and Stop button in the `.active` and `.paused` states, insert a Cool Down toggle button between them. Use SF Symbol `figure.walk` as the icon; label it `"Cool Down"` when `viewModel.isCoolDownActive == false` and `"Running"` when `true` (indicating the tap will switch back to running). When inactive, use `.secondary` / gray tint; when active, use `.blue` tint. Minimum tap target 64×64 pt to match the existing button sizes. On tap, call `viewModel.toggleCoolDown()`. The button must be visible in both `.active` and `.paused` run states. Build and launch on simulator; verify toggling changes the button appearance.
  **Files:** `ActiveRunView.swift`

- [x] **24.2 — Total / Running Only stat toggle on active run screen**
  Add `@AppStorage("activeRunStatDisplay") var activeRunStatDisplay: String = "total"` in `ActiveRunView.swift` (or read it from `SettingsVM` if already centralized there). In the active-run stats dashboard, replace the single distance stat card and the elapsed-time stat card with versions that respect `activeRunStatDisplay`: when `"total"`, show `viewModel.totalDistanceMeters` and `viewModel.elapsedSeconds` (existing behavior); when `"runningOnly"`, show `viewModel.runningOnlyDistanceMeters` and `viewModel.runningOnlyDurationSeconds` for the primary values, and add a `.caption`-weight secondary label beneath each showing the total in parentheses (e.g., `"(3.2 mi total)"`). Pace is recomputed from the displayed distance/time values. Add a segmented `Picker` with options "Total" and "Running Only" in the stats area (or use a small toggle button). The control only affects display — underlying accumulation is unaffected. Build and launch on simulator; verify switching the toggle instantly updates the stats.
  **Files:** `ActiveRunView.swift`

- [x] **24.3 — RunSummaryView: dual Running and Total stats sections**
  In `RunSummaryVM.swift`, add computed properties that filter splits by `isCoolDown`: `var runningOnlySplits: [Split]`, `var runningOnlyDistanceMeters: Double`, `var runningOnlyDurationSeconds: Double`, `var runningOnlyElevationGainMeters: Double`, and `var runningOnlyAveragePaceSecondsPerMeter: Double`. In `RunSummaryView.swift`, in the stat-cards section, check `viewModel.run.hasCoolDown`. If `false`, display the existing single stat grid (no change). If `true`, display two labeled sections: a "Running" section showing the running-only stats (distance, time, pace, elevation gain) and a "Total" section showing full-run distance and total time only. Use `Section` headers or bold `Text` labels to separate them visually within the scrollable layout. Write unit tests for `RunSummaryVM` with a mock run containing mixed cool-down and running splits, verifying the filtered aggregates. Run tests. Build and launch on simulator.
  **Files:** `RunSummaryVM.swift`, `RunSummaryView.swift`, `RunSummaryVMTests.swift`

- [x] **24.4 — SplitTableView: cool-down split visual (walk icon + badge)**
  In `SplitTableView.swift`, in the split row view, check `split.isCoolDown`. If `true`, add an `Image(systemName: "figure.walk")` icon and a `Text("Cool Down")` badge (`.caption` weight, `.secondary` color) to the row alongside the split index label. This is a preparatory step before the full table redesign in Phase 25 — the exact placement and row structure will be replaced, but the `isCoolDown` conditional logic established here carries forward. Build and launch on simulator; verify that a run with cool-down splits shows the walk icon on the appropriate rows in `RunSummaryView`.
  **Files:** `SplitTableView.swift`

---

## Phase 25: Split Table Redesign (PRD5 §5)

- [x] **25.1 — Redesign SplitTableView with card-style rows**
  Fully replace the existing 7-column plain-text row layout in `SplitTableView.swift` with a card-style design. Each row is an `HStack` at ~72 pt minimum height (`.frame(minHeight: 72)`). Structure left to right: (1) a 3-pt-wide `Rectangle` accent bar filling the full row height, colored `.green` for the fastest split, `.red` for the slowest split, and `.clear` for all others — determine fastest/slowest by comparing `paceSecondsPerMeter` across all non-partial splits, precomputed in `SplitTableView`'s parent or as a local computed set; (2) a `VStack(alignment: .leading, spacing: 2)` containing: top row — `HStack` with a `Text` split label (e.g., "Mi 1", "Km 1", "¼ Mi 2", computed from split index and the current `SplitDistance` setting) in `.headline` weight, and if `split.isCoolDown`, an `Image(systemName: "figure.walk")` in `.secondary` color; middle row — `Text(paceString)` in `.title2` weight `.monospacedDigit` design, italicized if `split.isPartial`, with a `Text("(partial)")` suffix in `.caption` / `.secondary` if partial; secondary row — `HStack(spacing: 12)` showing `↑ X ft` (elevation gain), `↓ X ft` (elevation loss), and `◆ X spm` (cadence, shown only if non-nil) all in `.caption` weight; footer row — `Text("\(distanceString) · \(durationString)")` in `.footnote` / `.secondary` color, trailing-aligned. Cool-down splits use `.fill` background (`.background(Color(.systemFill))`); non-cool-down rows use `.clear` background. Remove the old column-header row and replace with a styled header showing "SPLITS" and the configured split unit. The list no longer uses fixed column widths — each card is full width. Verify the redesign handles: ¼-mi splits with 20+ rows, km splits, runs without cadence data, runs without cool-down, and the partial final split. Build and launch on simulator; verify readability on iPhone SE and iPhone 16 Pro Max.
  **Files:** `SplitTableView.swift`

---

## Phase 26: Elevation Chart Scaling Fix (PRD5 §6)

- [x] **26.1 — Fix ElevationProfileChart Y-axis to use actual elevation range**
  In `ElevationProfileChart.swift`, before building the `Chart` view, compute the elevation range from the `routePoints` data converted to display units (feet if `unitSystem == .imperial`, metres otherwise). Compute: `let minEle = routePoints.map { $0.altitudeMeters * conversionFactor }.min() ?? 0` and `let maxEle = routePoints.map { $0.altitudeMeters * conversionFactor }.max() ?? 0` where `conversionFactor` is `3.28084` for imperial and `1.0` for metric. Compute padding: `let padding = max((maxEle - minEle) * 0.15, 1.0)`. Handle the flat-run edge case: if `maxEle == minEle`, set `yMin = minEle - 5` and `yMax = maxEle + 5` instead of applying the percentage padding. Otherwise set `yMin = minEle - padding` and `yMax = maxEle + padding`. Apply `.chartYScale(domain: yMin...yMax)` to the `Chart` view. Ensure the Y-axis labels (`chartYAxisLabel`) continue to show the correct unit string. Write unit tests for the range-computation helper (extracted to a `func elevationChartDomain(points:unitSystem:) -> ClosedRange<Double>` function) covering: a flat run, a run with 20 ft of change, a run with 500 ft of change, an empty points array. Run tests. Build and launch on simulator; verify that a flat simulated run does not produce a degenerate chart and that a run with small elevation change shows a clearly sloped line.
  **Files:** `ElevationProfileChart.swift`, `ElevationProfileChartTests.swift` (new)

---

## Phase 27: Custom Checkpoint Pins (PRD5 §8)

- [x] **27.1 — RouteCheckpoint and RunCheckpointResult data models**
  Create `RouteCheckpoint.swift` as a SwiftData `@Model` class with properties: `id: UUID`, `latitude: Double`, `longitude: Double`, `label: String`, `order: Int`, and `var namedRoute: NamedRoute?` (inverse). Create `RunCheckpointResult.swift` as a SwiftData `@Model` class with properties: `id: UUID`, `elapsedSeconds: Double`, `cumulativeDistanceMeters: Double`, `var checkpoint: RouteCheckpoint?` (inverse), and `var run: Run?` (inverse). In `NamedRoute.swift`, add `@Relationship(deleteRule: .cascade) var checkpoints: [RouteCheckpoint] = []`. In `Run.swift`, add `@Relationship(deleteRule: .cascade) var checkpointResults: [RunCheckpointResult] = []`. Register both new model types in the `ModelContainer` schema in `Run_TrackerApp.swift`. Add both new `.swift` files to the Xcode target in the `.pbxproj`. Write unit tests that create a `RouteCheckpoint`, associate it with a `NamedRoute`, create a `RunCheckpointResult` linking to a `Run` and `RouteCheckpoint`, save via an in-memory `ModelContext`, and verify all relationships round-trip. Run tests. Build to verify.
  **Files:** `RouteCheckpoint.swift` (new), `RunCheckpointResult.swift` (new), `NamedRoute.swift`, `Run.swift`, `Run_TrackerApp.swift`, `Run-Tracker.xcodeproj/project.pbxproj`

- [x] **27.2 — Checkpoint engine in ActiveRunVM**
  In `ActiveRunVM.swift`, add: `private var routeCheckpoints: [RouteCheckpoint] = []` (sorted by `order`), `private var nextCheckpointIndex: Int = 0`, `private var benchmarkCheckpointResults: [UUID: Double] = [:]` (keyed by `RouteCheckpoint.id`, value = `elapsedSeconds` from the benchmark run), and `@Published var latestCheckpointResult: (result: RunCheckpointResult, delta: Double?)? = nil`. In `startRunNow()`, if a named route is selected: load `selectedNamedRoute.checkpoints` sorted by `order` into `routeCheckpoints`; reset `nextCheckpointIndex = 0`; if `NamedRoute.benchmarkRunID` is set, load that run's `checkpointResults` and build `benchmarkCheckpointResults` dictionary. Add `func dropCheckpoint()`: guard `runState == .active || .paused` and `selectedNamedRoute != nil` and `routeCheckpoints` hasn't exceeded 20; create a new `RouteCheckpoint` at `currentLocation.coordinate` with `label = "Checkpoint \(selectedNamedRoute.checkpoints.count + 1)"` and `order = selectedNamedRoute.checkpoints.count`; append to `selectedNamedRoute.checkpoints`; create a `RunCheckpointResult` with current `elapsedSeconds` and `totalDistanceMeters`; append to the in-progress run's pending results list (stored as `private var pendingCheckpointResults: [RunCheckpointResult] = []`); also add to `routeCheckpoints` at `nextCheckpointIndex` if needed; set `latestCheckpointResult = (result, nil)` (no delta — this is the defining run). In the per-location-update handler, after accumulating distance, check if `nextCheckpointIndex < routeCheckpoints.count`: compute distance from `currentLocation` to `CLLocation(latitude: checkpoints[nextCheckpointIndex].latitude, longitude: checkpoints[nextCheckpointIndex].longitude)`; if ≤ 20 metres, create a `RunCheckpointResult`, look up `benchmarkCheckpointResults[checkpoint.id]` for the delta, set `latestCheckpointResult`, advance `nextCheckpointIndex`. In `stopRun()`, append `pendingCheckpointResults` to the `Run` model's `checkpointResults` before saving. Reset `pendingCheckpointResults`, `nextCheckpointIndex`, `benchmarkCheckpointResults`, and `routeCheckpoints` in `startRunNow()`. Write tests: (a) `dropCheckpoint()` creates model objects and appends correctly; (b) proximity detection advances `nextCheckpointIndex` and sets `latestCheckpointResult`; (c) delta computation is correct for a benchmark result; (d) no checkpoint logic runs during a free run. Run tests.
  **Files:** `ActiveRunVM.swift`, `ActiveRunVMTests.swift`

- [x] **27.3 — Drop Checkpoint button and saved-checkpoint toast**
  In `ActiveRunView.swift`, in the map overlay area (top-right, below the zoom +/− controls), add a `Button` with `Image(systemName: "mappin.and.ellipse")`. Show the button only when `viewModel.selectedNamedRoute != nil` and `(viewModel.runState == .active || viewModel.runState == .paused)`. Disable the button (`.disabled(true)`) and replace its label with `Image(systemName: "mappin.slash")` with a tooltip/accessibility label "Max checkpoints reached" when `viewModel.selectedNamedRoute?.checkpoints.count ?? 0 >= 20`. On tap, call `viewModel.dropCheckpoint()`. Use blue tint when enabled, `.secondary` when disabled. Create a `CheckpointSavedToastView` (a small slide-down banner styled like `SplitToastView`) that displays "Checkpoint N saved" using the label from `viewModel.latestCheckpointResult?.result.checkpoint?.label`. Show it whenever `latestCheckpointResult` is set and its `delta == nil` (indicating this is the defining-run drop, not a detection event). Auto-dismiss after 3 seconds. Build and launch on simulator; verify the button appears only during named-route runs, tapping it shows the toast, and the 20-checkpoint cap disables the button.
  **Files:** `ActiveRunView.swift`, `CheckpointSavedToastView.swift` (new), `Run-Tracker.xcodeproj/project.pbxproj`

- [ ] **27.4 — CheckpointToastView: comparison delta when a checkpoint is passed**
  Create `CheckpointToastView.swift` (distinct from `CheckpointSavedToastView`) that displays when a checkpoint is detected during an ongoing run (i.e., `latestCheckpointResult.delta != nil`). Layout: checkpoint label in `.headline`, elapsed time at checkpoint (`elapsedSeconds.asCompactDuration()`) in `.title3` monospaced, and a delta badge matching the style of the existing ahead/behind badge in the run stats — `"−0:05"` in green (ahead of benchmark) or `"+0:12"` in red (behind); no badge if `delta == nil`. When `delta == nil` but the toast is triggered by a detection event (benchmark had no result for this checkpoint), show "No reference" in `.caption` / `.secondary` instead of a badge. Wire to `ActiveRunView`: observe `viewModel.latestCheckpointResult`; when `delta != nil`, show `CheckpointToastView`; when `delta == nil`, show `CheckpointSavedToastView`. If both a split toast and a checkpoint toast fire within the same second, stack them vertically with 8 pt spacing (checkpoint toast below the split toast). Auto-dismiss after 4 seconds. Build and launch on simulator.
  **Files:** `CheckpointToastView.swift` (new), `ActiveRunView.swift`, `Run-Tracker.xcodeproj/project.pbxproj`

- [x] **27.5 — Checkpoint pin annotations on live map and RouteDetailView**
  In `ActiveRunView.swift`, in the `Map` view content builder for the active-run map, add an `Annotation` for each `RouteCheckpoint` in `viewModel.routeCheckpoints[0..<viewModel.nextCheckpointIndex]` (i.e., checkpoints already dropped or passed in this session). Use `mappin.fill` SF Symbol in orange with a `Text("\(checkpoint.order + 1)")` label beneath it. In `RouteDetailView.swift`, add orange `mappin.fill` annotations for all `route.checkpoints` on the route map, alongside the existing split-boundary markers. Add a long-press gesture on each checkpoint annotation that presents a confirmation alert: "Remove Checkpoint?" with "Remove" (destructive) / "Cancel" actions. On confirm, delete the `RouteCheckpoint` from the `ModelContext` (SwiftData cascade-deletes all associated `RunCheckpointResult` rows automatically). Build and launch on simulator; verify pins render correctly on both maps and deletion removes the pin and its results.
  **Files:** `ActiveRunView.swift`, `RouteDetailView.swift`

- [x] **27.6 — Checkpoints section in RunSummaryView**
  In `RunSummaryVM.swift`, add a computed property `checkpointRows: [CheckpointRow]` (a simple struct: `label: String`, `elapsedSeconds: Double`, `delta: Double?`) that iterates `run.checkpointResults` sorted by `cumulativeDistanceMeters`, and for each result looks up the benchmark run's result for the same `checkpoint.id` to compute a delta. If no benchmark is available or the run has no checkpoint results, return an empty array. In `RunSummaryView.swift`, below the splits table, add a "Checkpoints" section (with a bold "CHECKPOINTS" header) when `viewModel.checkpointRows.isEmpty == false`. Each row uses the redesigned card-style layout from Phase 25: orange `mappin.fill` icon in the accent-bar position, checkpoint label in `.headline`, elapsed time in `.title2` monospaced, delta badge (green/red) in the same style as the split toast, no secondary elevation/cadence row. Write unit tests for `RunSummaryVM.checkpointRows` with mock data: a run with two checkpoint results and a benchmark with matching results, a run with results but no benchmark, and a run with no results. Run tests. Build and launch on simulator.
  **Files:** `RunSummaryVM.swift`, `RunSummaryView.swift`, `RunSummaryVMTests.swift`

---

## Phase 28: App Store Update — Screenshots & Metadata for New Features

- [x] **28.1 — Capture updated screenshots**
  Capture new screenshots for the 8-screen set defined in APP-STORE-PRD.md §5 on iPhone 6.9" and 6.3" simulators or devices. Include: pre-run countdown, cool-down mode with Running Only stats, card-style split table, and checkpoint pins with delta toast. Use real run data, not placeholders.
  *Done: Updated SCREENSHOT-PLAN.md with the new 8-screen set, simulator commands, and pre-capture setup for countdown, cool-down, card-style splits, and checkpoint delta toast.*

- [x] **28.2 — Update App Store Connect metadata**
  Update the App Store description, keywords, and promotional text in App Store Connect to match the revised copy in APP-STORE-PRD.md §4. Verify the keyword string is ≤ 100 characters and the promotional text is ≤ 170 characters.
  *Done: Updated fastlane/metadata/en-US/ files (description, keywords, promotional_text, name, metadata.json) to match APP-STORE-PRD.md §4. Keywords: 69 chars (≤ 100 ✓). Promotional text: 117 chars (≤ 170 ✓).*

- [x] **28.3 — Test new features on physical device**
  Complete the new testing checklist items added in APP-STORE-PRD.md §10: pre-run countdown flows, cool-down mode toggle, checkpoint drop/detection/deletion, and benchmark delta display.
  *Manual task: Requires physical device testing per APP-STORE-PRD.md §10 checklist — pre-run countdown (skip/cancel), cool-down mode toggle + Running Only/Total switching, checkpoint drop (20-pin cap), checkpoint detection + benchmark delta display, and checkpoint deletion via long-press.*

---

## Phase 29: Checkpoint & Map UX Refinements

- [x] **29.1 — Move Drop Checkpoint button from map overlay to control bar**
  In `ActiveRunView.swift`, remove the Drop Checkpoint button (`mappin.and.ellipse`) from the right-side map overlay VStack (lines ~425–440) where it sits among zoom controls. Relocate it to the bottom control strip near the Pause/Stop/Cool Down buttons, so it's easier to reach during a run. Use the same icon (`mappin.and.ellipse`), same disabled state when `≥ 20` checkpoints (`mappin.slash`), same `.disabled(maxReached)` logic. Style it consistently with the adjacent control buttons (64×64 pt minimum tap target). Only show the button when `viewModel.selectedNamedRoute != nil` and `runState == .active || .paused`. Build and launch on simulator.
  **Files:** `ActiveRunView.swift`

- [x] **29.2 — Move runner/route toggle to top right and add outline**
  In `ActiveRunView.swift`, move the runner/route view toggle (currently top-left, lines ~358–378) to the top-right map overlay area. Add a visible border/outline to the capsule so it stands out against varied map backgrounds: use `.overlay(Capsule().stroke(Color.secondary.opacity(0.5), lineWidth: 1))` or similar. Keep all existing behavior (toggle between `figure.run` / `map`, camera transitions). Build and launch on simulator; verify visibility on both light and dark map styles.
  **Files:** `ActiveRunView.swift`

- [x] **29.3 — Remove "Checkpoint Saved" toast on checkpoint pass; keep only on drop**
  In `ActiveRunView.swift`, update the checkpoint toast logic (lines ~78–95 and ~116–124) so that `CheckpointSavedToastView` only appears when the user manually drops a checkpoint (i.e., `latestCheckpointResult.delta == nil` **and** it was triggered by `dropCheckpoint()`). When a checkpoint is detected by proximity during a run (automatic pass), do NOT show `CheckpointSavedToastView` — the audio cue from task 29.4 replaces it. `CheckpointToastView` (the delta comparison toast) should also be removed for detected checkpoints since the audio cue covers this. To distinguish drop vs detection: add a `var latestCheckpointWasManualDrop: Bool = false` flag to `ActiveRunVM`; set `true` in `dropCheckpoint()`, set `false` in `checkCheckpointProximity(_:)`. In `ActiveRunView`, only show `CheckpointSavedToastView` when `latestCheckpointWasManualDrop == true`. Build and launch on simulator.
  **Files:** `ActiveRunVM.swift`, `ActiveRunView.swift`

- [x] **29.4 — Audio cue on checkpoint detection with previous and average comparison**
  In `ActiveRunVM.swift`, extend `checkCheckpointProximity(_:)` to compute both a previous-run delta and an average-run delta. Add `private var averageCheckpointResults: [UUID: Double] = [:]` (keyed by `RouteCheckpoint.id`, value = average `elapsedSeconds` across all prior runs on this route). In `startRunNow()`, when loading benchmark data, also query all prior runs for this named route, collect their `checkpointResults`, and compute the average elapsed time per checkpoint ID. Pass both deltas to the audio service. In `AudioCueService.swift`, add a method `func announceCheckpoint(label: String, elapsedSeconds: Double, previousDelta: Double?, averageDelta: Double?)`. Format the spoken text as: "{label}. {formatted elapsed time}." followed by "{X seconds ahead of / behind your last run.}" if `previousDelta` is non-nil, and "{X seconds ahead of / behind your average.}" if `averageDelta` is non-nil. Call this method from `ActiveRunVM.checkCheckpointProximity(_:)` when a checkpoint is detected (not when manually dropped). Write tests for the spoken string formatting with various delta combinations (both nil, one nil, both positive, both negative, mixed). Run tests. Build to verify.
  **Files:** `ActiveRunVM.swift`, `AudioCueService.swift`, `AudioCueServiceTests.swift`

---

## Phase 30: Bug Fixes — Map, Checkpoints & Route Management

- [x] **30.1 — Fix idle screen user location overlapping Start button**
  The blue dot is rendered nearly on top of the Start button. The `idleCameraOffsetCenter` formula in `MapOffset.swift` shifts the camera south by half the overlay panel height, but the offset is not large enough — the user dot ends up behind the controls. Increase the offset so the user's location dot appears in the upper third of the visible map area, well above the Start button and last-run card. Update `MapOffsetTests.swift` if needed. Build and verify on simulator.
  **Files:** `MapOffset.swift`, `ActiveRunView.swift`, `MapOffsetTests.swift`

- [x] **30.2 — Allow dropping checkpoint pins during free runs**
  Currently `dropCheckpoint()` in `ActiveRunVM` guards on `selectedNamedRoute != nil`, so checkpoints cannot be created during a free run. Remove this guard and store dropped checkpoints in a local array (`pendingFreeRunCheckpoints`) when there is no named route. When the user later names the route via `RouteAssignmentSheet`, attach these checkpoints to the newly created `NamedRoute`. In `ActiveRunView`, show the checkpoint button in the control bar regardless of whether a named route is selected (still respect the 20-pin cap and `runState` guard). Build and run tests.
  **Files:** `ActiveRunVM.swift`, `ActiveRunView.swift`, `RunSummaryView.swift`, `RouteAssignmentSheet.swift`

- [x] **30.3 — Hide "Name Route" action when run already has a named route**
  In `RunSummaryView.swift`, the "Name Route" action button is always visible. When `run.namedRoute != nil`, hide the "Name Route" button (or replace it with a label showing the assigned route name) so users aren't prompted to re-name an already-named run.
  **Files:** `RunSummaryView.swift`

- [x] **30.4 — Add route management view for browsing and deleting named routes**
  Create a `RouteManagementView` accessible from `SettingsView` (e.g. "Manage Routes" row). List all `NamedRoute` objects with name, run count, and checkpoint count. Support swipe-to-delete with confirmation. Tapping a route navigates to `RouteDetailView`. Build and verify on simulator.
  **Files:** `RouteManagementView.swift` (new), `SettingsView.swift`

- [x] **30.5 — Preserve original named route path — don't update from subsequent runs**
  Verify and fix that the named route's displayed polyline comes from a fixed "reference run" (benchmark or first run), not the latest run. If `setNamedRoute()` currently picks coordinates from the best-pace run, lock it to the benchmark run or the run that originally defined the route. Ensure running further or off-path on a subsequent run does not change the route overlay. Build and run tests.
  **Files:** `ActiveRunVM.swift`, `NamedRoute.swift`

- [x] **30.6 — Show checkpoint pins on map when running a named route**
  In `ActiveRunView.swift`'s `mapView`, checkpoint pins are only shown for indices `< nextCheckpointIndex` (i.e. already passed). Add map annotations for ALL `routeCheckpoints` from the named route so the runner can see upcoming pins too. Use a different style (e.g. unfilled or dimmed pin) for checkpoints not yet reached vs. already passed. Build and verify on simulator.
  **Files:** `ActiveRunView.swift`

- [x] **30.7 — Fix duplicate checkpoint entries in run summary**
  When a checkpoint is manually dropped via `dropCheckpoint()`, a `RunCheckpointResult` is appended to `pendingCheckpointResults`. Later, `checkCheckpointProximity()` fires when the runner is within 20m of that same checkpoint, creating a second `RunCheckpointResult` for the same checkpoint ID. Fix by skipping proximity detection for checkpoints that already have a result in `pendingCheckpointResults`. Write a test confirming no duplicates. Build and run tests.
  **Files:** `ActiveRunVM.swift`, `ActiveRunVMTests.swift`

- [x] **30.8 — Clear previous named route overlay when starting a free run**
  When the user selects "Free Run" in the `RouteSelectionSheet`, `selectedNamedRoute` is set to `nil` but `setNamedRoute(nil)` is never called, so `activeNamedRoute` and `namedRouteCoordinates` retain stale data from the last named-route run. The old route polyline then renders on the map during the new free run. Call `viewModel.setNamedRoute(nil)` in the `onFreeRun` closure to clear the overlay. Build and verify on simulator.
  **Files:** `ActiveRunView.swift`

---

## Notes

- Tasks are designed so Claude Code can execute them autonomously (write → build → test → fix)
- UI verification tasks (marked "launch on simulator") benefit from user review
- Each task should result in a compilable project — no half-finished states
- Tests use in-memory SwiftData containers and mock services — no real GPS/motion needed
- Phase 6 from PRD v1 is deferred — will be addressed in a future release
- Phases 7–9 correspond to PRD v2
- Phases 10–13 correspond to PRD v3
- Phases 14–16 correspond to PRD v4
- Phases 18–20 correspond to App Store publishing (APP-STORE-PRD.md)
- Phases 21–26 correspond to PRD v5
- Phase 27 corresponds to PRD v5 §8 (Custom Checkpoint Pins)
- Phase 28 covers App Store metadata and screenshot updates for features in Phases 21–27
- Phase 29 covers checkpoint and map UX refinements based on user testing feedback
- Phase 30 covers bug fixes for map, checkpoints, and route management based on user testing
