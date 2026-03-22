# Run Tracker — Screenshot Capture Plan

## Required Device Sizes

| Device | Simulator | Screenshot Size (pixels) |
|--------|-----------|-------------------------|
| iPhone 6.9" | iPhone 16 Pro Max | 1320 × 2868 |
| iPhone 6.3" | iPhone 16 Pro | 1206 × 2622 |

## Screenshots (8 per device, light + dark mode)

| # | Screen | Navigation | Key Caption |
|---|--------|-----------|-------------|
| 1 | Active Run | Start a run, let it track for ~1 min with visible route, pace, distance, and timer | "Track Every Step in Real Time" |
| 2 | Pre-Run Countdown | Tap Start Run — capture the countdown overlay with large pulsing digit on the map | "Get Set with a Countdown" |
| 3 | Run Summary | Tap Stop on a run that used cool-down mode — show Running/Total dual stat sections | "Detailed Run Summaries" |
| 4 | Splits View | Open a run summary, scroll to the card-style split table with accent bars for fastest/slowest | "Analyze Every Split" |
| 5 | Cool-Down Mode | During an active run, tap Cool Down — toggle to Running Only stats view | "Separate Your Cool Down" |
| 6 | Checkpoints | Run a named route with checkpoint pins — capture the delta toast showing ahead/behind | "Set Checkpoints, Beat Your Time" |
| 7 | Run History | Tab bar → History — show multiple past runs with search bar visible | "Your Complete Run History" |
| 8 | Offline Maps | Tab bar → Settings → Download Map Area, or show offline badge on map | "Run Anywhere, Even Offline" |

## Pre-Capture Setup

1. **Populate test data** — Run the app on the simulator and create several runs with varied distances (1–5 miles). Name at least 2 routes. Ensure weather data is present on some runs.

2. **Realistic GPS data** — Use the simulator's location simulation (Freeway Drive, City Run) to generate GPS traces with real-looking routes.

3. **Named route with checkpoints** — Create a named route and drop 3–4 checkpoint pins along it. Then run the same route again so checkpoint detection fires and delta toasts appear.

4. **Cool-down data** — On at least one run, engage Cool Down mode partway through so the summary shows both Running and Total stat sections, and the split table includes cool-down splits with visual distinction.

5. **Settings** — Set unit system to imperial (miles). Enable audio cues with splits + time interval.

## Capture Steps

### For each device simulator:

1. Boot simulator:
   ```bash
   xcrun simctl boot "iPhone 16 Pro Max"
   ```

2. Install app:
   ```bash
   xcrun simctl install booted path/to/Run-Tracker.app
   ```

3. Launch app:
   ```bash
   xcrun simctl launch booted sawtoothdata.Run-Tracker
   ```

4. Navigate to each screen and capture:
   ```bash
   # Screen 1: Active Run — start a run, wait ~1 min for route to draw
   xcrun simctl io booted screenshot screenshots/6.9/01-active-run-light.png

   # Screen 2: Pre-Run Countdown — tap Start Run, capture during countdown
   xcrun simctl io booted screenshot screenshots/6.9/02-countdown-light.png

   # Screen 3: Run Summary — stop a run that used cool-down mode
   xcrun simctl io booted screenshot screenshots/6.9/03-run-summary-light.png

   # Screen 4: Splits View — scroll to card-style split table in summary
   xcrun simctl io booted screenshot screenshots/6.9/04-splits-light.png

   # Screen 5: Cool-Down Mode — engage cool-down, toggle to Running Only
   xcrun simctl io booted screenshot screenshots/6.9/05-cooldown-light.png

   # Screen 6: Checkpoints — run named route, wait for checkpoint delta toast
   xcrun simctl io booted screenshot screenshots/6.9/06-checkpoints-light.png

   # Screen 7: Run History — navigate to History tab
   xcrun simctl io booted screenshot screenshots/6.9/07-history-light.png

   # Screen 8: Offline Maps — open map download screen or show offline badge
   xcrun simctl io booted screenshot screenshots/6.9/08-offline-maps-light.png
   ```

5. Switch to dark mode:
   ```bash
   xcrun simctl ui booted appearance dark
   ```

6. Repeat captures for dark mode (e.g., `01-active-run-dark.png`, etc.)

7. Reset to light mode when done:
   ```bash
   xcrun simctl ui booted appearance light
   ```

### Output Directory Structure

```
screenshots/
├── 6.9/
│   ├── 01-active-run-light.png
│   ├── 01-active-run-dark.png
│   ├── 02-countdown-light.png
│   ├── 02-countdown-dark.png
│   ├── 03-run-summary-light.png
│   ├── 03-run-summary-dark.png
│   ├── 04-splits-light.png
│   ├── 04-splits-dark.png
│   ├── 05-cooldown-light.png
│   ├── 05-cooldown-dark.png
│   ├── 06-checkpoints-light.png
│   ├── 06-checkpoints-dark.png
│   ├── 07-history-light.png
│   ├── 07-history-dark.png
│   ├── 08-offline-maps-light.png
│   └── 08-offline-maps-dark.png
└── 6.3/
    └── (same structure)
```

## Post-Capture

- Optionally add device frames using Fastlane Frameit or RocketSim
- Add caption text overlays for App Store listing
- Verify no alpha channel in final PNGs
