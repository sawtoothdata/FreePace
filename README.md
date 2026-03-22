# FreePace

A free, open-source GPS running app for iPhone. Track runs with live mapping, pace splits, cadence, audio coaching, route checkpoints, and detailed analysis — all with your data stored locally on your device.

**Available on the [App Store](https://apps.apple.com/ca/app/freepace/id6760371864)**

**Platform:** iOS 17+, iPhone only
**Architecture:** MVVM + Service Layer
**Built with:** SwiftUI, SwiftData, MapKit, Core Location, Core Motion, AVSpeechSynthesizer, WeatherKit

---

## Features

- **Live run tracking** — GPS route, distance, pace, elevation, cadence, and duration updated in real time
- **Interactive map** — Route colored by elevation or pace, time markers, and adjustable zoom
- **Cool-down mode** — Separate warm-down stats from your run with a single tap
- **Named routes & checkpoints** — Save routes, drop checkpoint pins, and track performance over time
- **Coach mode** — Live ahead/behind pace comparison against your benchmark run with audio coaching
- **Audio cues** — Configurable spoken updates at splits and time intervals (works with screen locked)
- **Splits** — Configurable split distances (quarter, half, full mile/km) with toast notifications
- **Run summary** — Post-run stats, elevation profile chart, split table, route map, and weather data
- **Run history** — Sortable/filterable list with search by date, distance, duration, pace, and route
- **Data explorer** — Chart any metric against any other across all your runs with trend lines
- **GPX import/export** — Import runs from other apps, export individual or bulk GPX/CSV files
- **Weather capture** — Automatic temperature, humidity, wind, and conditions via WeatherKit
- **Dark mode** — Full dark mode support with system, light, or dark options
- **Offline maps** — Download and cache map tiles for running without internet
- **Background running** — Continues tracking and audio cues with the screen locked

---

## Getting Started

### Prerequisites

- Xcode 15+ with iOS 17 SDK
- An Apple Developer account (free or paid) for signing

### Setup

1. Clone the repo
2. Copy `.env.example` to `.env` and fill in your values (for reference only)
3. Open `Run-Tracker/Run-Tracker.xcodeproj` in Xcode
4. Select your Development Team under **Signing & Capabilities**
5. Update the Bundle Identifier to your own (e.g., `com.yourname.FreePace`)
6. Build and run on a simulator or device

```bash
cd Run-Tracker

# Build
xcodebuild -project Run-Tracker.xcodeproj -scheme Run-Tracker \
  -sdk iphonesimulator -configuration Debug build

# Run tests
xcodebuild test -project Run-Tracker.xcodeproj -scheme Run-Tracker \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## Project Structure

```
Run-Tracker/
├── Run-Tracker/
│   ├── App/                  # App entry point, ModelContainer setup
│   ├── Models/               # SwiftData @Model classes
│   │   ├── Run.swift
│   │   ├── Split.swift
│   │   ├── RoutePoint.swift
│   │   ├── NamedRoute.swift
│   │   ├── RouteCheckpoint.swift
│   │   ├── RunCheckpointResult.swift
│   │   ├── AudioCueConfig.swift
│   │   └── UnitSystem.swift
│   ├── ViewModels/           # @Observable view models
│   │   ├── ActiveRunVM.swift
│   │   ├── RunSummaryVM.swift
│   │   ├── RunHistoryVM.swift
│   │   ├── RouteComparisonVM.swift
│   │   ├── DataExplorerVM.swift
│   │   └── SettingsVM.swift
│   ├── Services/             # Location, motion, audio, persistence, GPX, weather, caching
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
│   ├── Views/                # SwiftUI screens and components
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

## Key Conventions

- All distances stored internally in **meters**, durations in **seconds**
- Conversion to display units happens in ViewModels/Extensions only
- `@Observable` (iOS 17 Observation framework) for view models
- `@AppStorage` for user preferences (units, appearance, audio settings)
- Unit tests use in-memory SwiftData containers and mock services — no real GPS/motion needed

---

## Why FreePace?

- **No account required** — open the app and run
- **No subscriptions** — every feature is free, forever
- **No ads** — a clean experience with zero interruptions
- **No data collection** — everything stays on your device
- **Battery efficient** — GPS is active only during runs

---

## Privacy

All data is stored locally on your device. No accounts, no cloud sync, no analytics, no ads. See [PRIVACY-POLICY.md](PRIVACY-POLICY.md) for details.

---

## License

See [LICENSE](LICENSE) for details.

---

## Support

For questions, bug reports, or feature requests, please [open an issue](https://github.com/sawtoothdata/FreePace/issues).
