# Run Tracker — Development Process

**Project:** Run-Tracker Xcode project
**Scheme:** `Run-Tracker`
**Display Name:** FreePace
**Target:** iOS 17+, iPhone only
**Architecture:** MVVM + Service Layer

---

## Build & Test Commands

```bash
# Working directory
cd Run-Tracker

# Build (simulator)
xcodebuild -project Run-Tracker.xcodeproj -scheme Run-Tracker -sdk iphonesimulator -configuration Debug build

# Run unit tests
xcodebuild test -project Run-Tracker.xcodeproj -scheme Run-Tracker -destination 'platform=iOS Simulator,name=iPhone 16'

# Boot simulator and launch app
xcrun simctl boot "iPhone 16"

# Install and launch on simulator
xcodebuild -project Run-Tracker.xcodeproj -scheme Run-Tracker -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build
xcrun simctl install booted Build/Products/Debug-iphonesimulator/Run-Tracker.app
xcrun simctl launch booted <your-bundle-id>
```

---

## Development Loop

Each task follows this cycle:

1. **Write code** — Create/edit Swift files following the folder structure below
2. **Build** — Run `xcodebuild build` to catch compiler errors
3. **Fix errors** — Read compiler output, fix issues, rebuild
4. **Write tests** — Add XCTests for new logic (services, view models, data model)
5. **Run tests** — Run `xcodebuild test`, read output
6. **Fix failures** — Iterate until tests pass
7. **Verify on simulator** — Boot and launch for visual/integration checks when needed

Claude Code handles steps 1-6 autonomously. Step 7 is for user verification of UI/UX.

---

## Project Folder Structure

```
Run-Tracker/
├── Run-Tracker/
│   ├── App/
│   │   └── Run_TrackerApp.swift
│   ├── Models/
│   │   ├── Run.swift
│   │   ├── Split.swift
│   │   ├── RoutePoint.swift
│   │   ├── NamedRoute.swift
│   │   ├── RouteCheckpoint.swift
│   │   ├── RunCheckpointResult.swift
│   │   ├── AudioCueConfig.swift
│   │   └── UnitSystem.swift
│   ├── ViewModels/
│   │   ├── ActiveRunVM.swift
│   │   ├── RunSummaryVM.swift
│   │   ├── RunHistoryVM.swift
│   │   ├── RouteComparisonVM.swift
│   │   ├── DataExplorerVM.swift
│   │   └── SettingsVM.swift
│   ├── Services/
│   │   ├── LocationManager.swift
│   │   ├── MotionManager.swift
│   │   ├── SplitTracker.swift
│   │   ├── ElevationFilter.swift
│   │   ├── AudioCueService.swift
│   │   ├── RunPersistenceService.swift
│   │   ├── GPXExportService.swift
│   │   ├── GPXImportService.swift
│   │   ├── CSVExportService.swift
│   │   ├── WeatherService.swift
│   │   └── MapTileCacheService.swift
│   ├── Views/
│   │   ├── ActiveRunView.swift
│   │   ├── RunSummaryView.swift
│   │   ├── RunHistoryListView.swift
│   │   ├── RouteDetailView.swift
│   │   ├── RouteManagementView.swift
│   │   ├── DataExplorerView.swift
│   │   ├── DownloadMapAreaView.swift
│   │   ├── GPXImportPreviewView.swift
│   │   ├── SettingsView.swift
│   │   └── Components/
│   │       ├── StatCard.swift
│   │       ├── SplitTableView.swift
│   │       ├── ElevationProfileChart.swift
│   │       ├── GPSSignalIndicator.swift
│   │       ├── OfflineMapBadge.swift
│   │       ├── RouteAssignmentSheet.swift
│   │       ├── RouteSelectionSheet.swift
│   │       ├── RouteSnapshotView.swift
│   │       ├── SplitToastView.swift
│   │       ├── CheckpointToastView.swift
│   │       ├── CheckpointSavedToastView.swift
│   │       └── LongPressButton.swift
│   ├── Extensions/
│   │   ├── Double+Formatting.swift
│   │   ├── Date+Formatting.swift
│   │   ├── ElevationColor.swift
│   │   ├── PaceColor.swift
│   │   ├── MapOffset.swift
│   │   └── BearingUtils.swift
│   ├── Assets.xcassets/
│   └── Info.plist
├── Run-TrackerTests/
│   ├── RunPersistenceServiceTests.swift
│   ├── UnitConversionTests.swift
│   ├── DateFormattingTests.swift
│   ├── ElevationColorTests.swift
│   ├── ElevationProfileChartTests.swift
│   ├── MapOffsetTests.swift
│   ├── BearingUtilsTests.swift
│   ├── Services/
│   │   ├── ElevationFilterTests.swift
│   │   ├── SplitTrackerTests.swift
│   │   ├── GPXExportServiceTests.swift
│   │   ├── GPXImportServiceTests.swift
│   │   └── AudioCueServiceTests.swift
│   └── ViewModels/
│       ├── ActiveRunVMTests.swift
│       ├── RunSummaryVMTests.swift
│       ├── RunHistoryVMTests.swift
│       └── RouteComparisonVMTests.swift
└── Run-Tracker.xcodeproj/
```

---

## Implementation Phases

### Phase 1: Foundation (Data + Core Services)
Set up data models, unit system, persistence, and core services that everything else depends on. All testable without UI.

### Phase 2: Run Engine (Location + Motion + Splits)
Build the tracking engine: GPS, pedometer, elevation filtering, split detection. Test with mock data.

### Phase 3: Active Run UI (Map + Stats + Controls)
Wire up the active run screen: map, live stats dashboard, start/stop/pause controls.

### Phase 4: Post-Run (Summary + History)
Build run summary view, history list with sort/filter, route detail.

### Phase 5: Polish Features (Audio, Export, Routes, Dark Mode, Offline)
Add audio cues, GPX export, named routes, dark mode, offline maps.

### Phase 6: Integration & Edge Cases (DEFERRED)
End-to-end testing, edge case handling, battery optimization, final polish.

### Phases 7–9: Bug Fixes, UI Improvements, Route Overlay (PRD v2)
Stop button fix, larger controls, history fix, audio fix, configurable splits, app icon, map zoom, route overlay, elevation polyline, time markers.

### Phases 10–13: Quick Fixes, Route Selection, Route Detail, Coach Mode (PRD v3)
Icon redesign, split labels, action button restyle, route picker at start, route detail overhaul, coach mode.

### Phase 14: Landing Page & Background Running (PRD v4)
Tighter map zoom, remove mi/km label, last run card, background location/audio hardening.

### Phase 15: Weather Data Capture (PRD v4)
WeatherKit integration, weather fields on Run model, display on summary and history.

### Phase 16: Run Import (PRD v4)
GPX import service, stats computation, preview screen, file picker, bulk export.


---

## Testing Strategy

- **Unit tests** for all services and view models (pure logic, mock dependencies)
- **Model tests** for SwiftData entities (CRUD, relationships, constraints)
- **No UI tests in v1** — manual verification on simulator for UI/UX
- **Mock location data** for testing tracking logic without real GPS
- Tests should be fast and deterministic — no real timers, no network

---

## Key Conventions

- All distances stored internally in **meters**, durations in **seconds**
- Conversion to display units happens in ViewModels/Extensions only
- Use `@Observable` (iOS 17 Observation framework) for view models
- Use `@AppStorage` for user preferences (units, appearance, audio settings)
- Follow existing Xcode naming: files use PascalCase, the module is `Run_Tracker`
- New files must be added to the Xcode project (pbxproj) to compile
