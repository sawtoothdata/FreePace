# Run Tracker — Product Requirements Document v4

**Version:** 4.0
**Last updated:** 2026-03-08
**Builds on:** PRD v3 (Phases 10–13 complete)
**Platform:** iOS 17+, iPhone only
**Tech stack:** Swift, SwiftUI, MapKit, Core Location, Core Motion, SwiftData, AVSpeechSynthesizer, WeatherKit

---

## Table of Contents

1. [Overview](#1-overview)
2. [Landing Page Refinements](#2-landing-page-refinements)
3. [Background & Lock Screen Running](#3-background--lock-screen-running)
4. [Weather Data Capture](#4-weather-data-capture)
5. [Run Import & Export](#5-run-import--export)
6. [Data Model Changes](#6-data-model-changes)

---

## 1. Overview

PRD v4 focuses on real-world usability, data richness, and polish:

1. **Landing page refinements** — Tighter zoom on current location, remove mi/km label.
2. **Background running** — Ensure the app tracks and speaks audio cues with the screen off / phone in pocket.
3. **Weather data** — Capture temperature, humidity, and conditions for each run.
4. **Run import** — Add GPX import to complement the existing GPX export.

---

## 2. Landing Page Refinements

### Problem

The idle/landing screen map is too zoomed out and includes a redundant "miles" / "km" label below the Start button that adds no value.

### Changes

1. **Tighter map zoom** — Set the idle map to a closer zoom level (e.g., `MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)`) so the user can see their immediate surroundings — streets, trails, landmarks. The current `.userLocation(fallback: .automatic)` default is too far out.
2. **Remove mi/km label** — Delete the `Text(unitSystem == .imperial ? "miles" : "km")` below the Start button. The unit system is already set in Settings and visible in the stats dashboard.
3. **Show recent run summary** — Below or around the Start button area, show a compact summary of the user's last run (date, distance, pace) as motivation context. If no runs exist, show nothing extra.

### Acceptance Criteria

- [ ] Idle map is zoomed to ~street level centered on user's location.
- [ ] The mi/km label is removed from the idle screen.
- [ ] Last run summary card appears below Start button when a previous run exists.
- [ ] Clean, uncluttered layout on all iPhone sizes.

---

## 3. Background & Lock Screen Running

### Problem

When the user turns off the screen or puts the phone in their pocket during a run, the app must continue tracking GPS, accumulating distance, counting splits, and firing audio cues without interruption.

### Current State

The app already has:
- `UIBackgroundModes: location` in Info.plist
- `allowsBackgroundLocationUpdates = true` in `LocationManager`
- `AVAudioSession.setCategory(.playback, options: .duckOthers)` in `AudioCueService`

### Gaps to Address

1. **`showsBackgroundLocationIndicator`** — Set to `true` on `CLLocationManager` so iOS shows the blue location pill in the status bar, which also signals to the system that the app legitimately uses background location.
2. **"Always" location permission** — Currently requests `.whenInUse`. When the screen is locked and the app is no longer "in use", iOS may throttle or stop location updates. Request `.requestAlwaysAuthorization()` and add `NSLocationAlwaysAndWhenInUseUsageDescription` to Info.plist.
3. **Audio session persistence** — The current implementation deactivates the audio session after each utterance (`speechSynthesizer(_:didFinish:)` calls `deactivateAudioSession()`). This is fine for foreground, but in background the session should stay active during an active run to prevent iOS from suspending the app between cues. Keep the session active while `runState == .active`, only deactivate on `stopRun()`.
4. **Timer continuity** — The Combine `Timer.publish` used for the 1-second elapsed time counter and audio cue interval checks uses `RunLoop.main` which may not fire in background. Switch to a `DispatchSourceTimer` on a background queue, or use `Timer.publish(every:on:in:)` with `.common` run loop mode (which is already used — verify it works in background testing).
5. **Prevent idle screen dimming during active run** — Set `UIApplication.shared.isIdleTimerDisabled = true` when a run starts, and `false` when it stops. This keeps the screen on while the user is actively looking at it, but they can still manually lock the screen.
6. **Info.plist additions** — Add `NSLocationAlwaysAndWhenInUseUsageDescription` with an appropriate message.

### Acceptance Criteria

- [ ] GPS tracking continues uninterrupted when the screen is locked.
- [ ] Audio cues (split and time-interval) fire correctly with the screen off.
- [ ] The blue location indicator appears in the status bar during background tracking.
- [ ] The elapsed timer continues accurately in background.
- [ ] Screen does not auto-dim during an active run (user can still manually lock).
- [ ] App resumes to the active run screen when unlocked.

### Technical Notes

- Background location + audio playback background modes should be sufficient. The `audio` background mode could be added to Info.plist for extra safety, but `.playback` category with `duckOthers` on an active audio session should keep the app alive.
- Test on a real device — simulators don't accurately replicate background behavior.
- Consider adding a `beginBackgroundTask` as a safety net during the transition to background.

---

## 4. Weather Data Capture

### Problem

The user wants to correlate run performance with weather conditions — temperature, humidity, and general conditions (sunny, rainy, etc.).

### Approach: WeatherKit

Apple's WeatherKit (available iOS 16+) provides current weather data for a location. It requires an Apple Developer Program membership and a WeatherKit entitlement, but offers generous free-tier usage (500K calls/month).

**Alternative: OpenWeatherMap** — If WeatherKit setup is too heavy, use the OpenWeatherMap free API (60 calls/min, 1M calls/month). This requires an API key but avoids Apple entitlements. Given this is a personal app, either approach works.

### Data to Capture

At run start, fetch and store:
- **Temperature** (°F / °C, following unit system)
- **Feels-like temperature** (wind chill / heat index)
- **Humidity** (percentage)
- **Wind speed** (mph / km/h)
- **Conditions** (clear, cloudy, rain, snow — stored as a string/enum)

### Where to Display

1. **Run Summary** — Show a weather section with temperature, humidity, wind, and a condition icon (SF Symbols: `sun.max.fill`, `cloud.fill`, `cloud.rain.fill`, etc.)
2. **History list** — Optionally show a small weather icon next to each run
3. **Run model** — Store weather fields on the `Run` entity for historical analysis

### Time of Day

The app already stores `startDate` on each run. Add a computed `timeOfDay` property (Morning/Afternoon/Evening/Night) based on the start time and a `timeOfDayLabel` display string. The `Date+Formatting` extension already has `timeOfDayLabel` — just surface it more prominently on the run summary.

### Acceptance Criteria

- [ ] Weather data is fetched at run start and stored on the `Run` model.
- [ ] Temperature, humidity, wind, and conditions are shown on `RunSummaryView`.
- [ ] Weather data is displayed in the user's preferred unit system.
- [ ] A weather condition icon appears on history list rows.
- [ ] Time of day label is visible on the run summary header.
- [ ] Weather fetch failure is handled gracefully (run still works, weather section shows "unavailable").

### Technical Notes

- Use `WeatherService.shared.weather(for: CLLocation)` to get `CurrentWeather`.
- Map `CurrentWeather.condition` to an SF Symbol name and a display string.
- Store raw values in metric (Celsius, m/s) and convert for display, matching the existing pattern.
- Weather fetch is async — fire-and-forget at run start, update the Run when results arrive.

---

## 5. Run Import & Export

### Current State

GPX export is fully implemented: `GPXExportService` generates GPX 1.1 XML, and `RunSummaryView` has a `ShareLink` to export individual runs.

### New: GPX Import

Allow users to import GPX files to add historical runs from other apps (Strava, Garmin, Nike Run Club, etc.).

### Import Flow

1. **Entry point:** Add an "Import Run" button in the History tab (toolbar button or empty-state action).
2. **File picker:** Use `.fileImporter(isPresented:allowedContentTypes:)` with `UTType.gpx` (or `.xml` as fallback).
3. **Parse GPX:** Create a `GPXImportService` that:
   - Parses the GPX XML (use `XMLParser` or a lightweight approach)
   - Extracts `<trkpt>` elements with lat, lon, ele, time
   - Handles multiple `<trkseg>` as pause/resume gaps
   - Computes distance, duration, elevation gain/loss, splits, and pace from the raw points
4. **Preview:** Show an import preview screen with the parsed run summary (date, distance, duration, route map) and a "Save" button.
5. **Save:** Create a `Run` with computed stats, `Split`s, and `RoutePoint`s.

### Bulk Export

Add a "Export All" option that bundles all runs into a single GPX file (one `<trk>` per run) or generates a ZIP of individual GPX files.

### Acceptance Criteria

- [ ] Users can import a GPX file from the History screen.
- [ ] Imported runs appear in history with correct stats (distance, duration, pace, elevation).
- [ ] Import handles GPX files from major running apps (Strava, Garmin).
- [ ] Import preview shows a summary before saving.
- [ ] Invalid or unsupported GPX files show a clear error message.
- [ ] "Export All" option is available in Settings or History.

### Technical Notes

- Register `UTType.gpx` in Info.plist so the app can open GPX files from Files, email, etc.
- GPX format: `<gpx><trk><trkseg><trkpt lat="" lon=""><ele/><time/></trkpt></trkseg></trk></gpx>`
- Splits must be recomputed from the imported route points using `SplitTracker` logic.
- Set `isResumePoint = true` on the first point of each new `<trkseg>` after the first.

---

## 6. Data Model Changes

### Run Model — New Properties

```swift
// Weather data
var temperatureCelsius: Double?
var feelsLikeCelsius: Double?
var humidityPercent: Double?     // 0.0–1.0
var windSpeedMPS: Double?        // meters per second
var weatherCondition: String?    // "clear", "cloudy", "rain", "snow", etc.
var weatherConditionSymbol: String? // SF Symbol name

```

### New Services

```swift
// Weather
WeatherService — Fetches current weather at run start
GPXImportService — Parses GPX files into Run data
```

---

*End of PRD v4.*
