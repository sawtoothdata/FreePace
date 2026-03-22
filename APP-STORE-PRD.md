# Run Tracker — App Store Publishing PRD

**Version:** 1.1
**Last updated:** 2026-03-12
**Bundle ID:** `sawtoothdata.FreeRun`
**Platform:** iOS 17+, iPhone only

---

## Table of Contents

1. [App Icon](#1-app-icon)
2. [Launch Screen](#2-launch-screen)
3. [App Store Connect Metadata](#3-app-store-connect-metadata)
4. [App Description & Keywords](#4-app-description--keywords)
5. [Screenshots](#5-screenshots)
6. [URLs](#6-urls)
7. [Age Rating, Pricing & Availability](#7-age-rating-pricing--availability)
8. [Privacy Policy & Permissions](#8-privacy-policy--permissions)
9. [Info.plist Privacy Usage Descriptions](#9-infoplist-privacy-usage-descriptions)
10. [Pre-Submission Checklist](#10-pre-submission-checklist)

---

## 1. App Icon

**Status:** An `AppIcon.appiconset` exists in `Assets.xcassets` with a single `AppIcon.png`.

### Requirements

- Provide a single 1024×1024px PNG in the asset catalog (Xcode 15+ auto-generates all sizes from this)
- No transparency, no alpha channel
- No rounded corners (iOS applies the mask automatically)
- The icon should convey running/movement — consider a stylized route line, runner silhouette, or footprint motif using the app's accent color palette

### Design Guidelines

- Keep it simple and recognizable at small sizes (29pt, 40pt)
- Test visibility on both light and dark wallpapers
- Avoid text in the icon — it becomes unreadable at smaller sizes

### Deliverable

| Asset | Size | Format | Location |
|-------|------|--------|----------|
| AppIcon | 1024×1024 | PNG (no alpha) | `Assets.xcassets/AppIcon.appiconset/` |

---

## 2. Launch Screen

**Status:** ✅ Implemented via Option B (Info.plist `UILaunchScreen` with `SystemBackgroundColor`).

### Options

**Option A — Storyboard Launch Screen (recommended for v1):**
- Create `LaunchScreen.storyboard` with the app icon centered on a solid background matching the app's primary color
- Set in target → General → App Icons and Launch Screen → Launch Screen File

**Option B — Info.plist Launch Screen (simpler):**
- Add `UILaunchScreen` key to Info.plist with background color and optional image
- No storyboard file needed

### Requirements

- Must not contain dynamic content or text that needs localization for v1
- Should feel consistent with the first screen the user sees (the run dashboard)
- Background color should match the app's primary background (system background for dark mode support)

---

## 3. App Store Connect Metadata

Fill in the following fields in App Store Connect:

| Field | Value |
|-------|-------|
| **App Name** | FreePace |
| **Subtitle** | GPS Running & Route Recorder |
| **Primary Language** | English (U.S.) |
| **Bundle ID** | `sawtoothdata.FreeRun` |
| **SKU** | `freepace-ios-v1` |
| **Primary Category** | Health & Fitness |
| **Secondary Category** | Sports |
| **Content Rights** | Does not contain third-party content |

---

## 4. App Description & Keywords

### App Store Description

> Track your runs with precision GPS mapping, live pace and cadence data, cool-down mode, route checkpoints, and detailed split analysis — all in a clean, battery-efficient interface designed for runners.
>
> **Live Run Tracking**
> A 10-second countdown gets you ready, then your route is drawn in real time on the map. Get live updates on distance, pace, elapsed time, and elevation gain as you go. Pause and resume freely — Run Tracker keeps accurate records even through breaks.
>
> **Pre-Run Countdown**
> A 10-second countdown gives you time to pocket your phone and get set before your run begins. Tap anywhere to skip the countdown or cancel to go back.
>
> **Audio Cues**
> Receive spoken updates at each mile or kilometer split so you can stay informed without looking at your phone. Customize which stats are announced. Audio cues automatically adapt when you enter cool-down mode.
>
> **Cool-Down Mode**
> Tap the Cool Down button mid-run to separate your warm-down walk from your running stats. View running-only or total stats on the fly with a simple toggle. Your run summary automatically shows both running and total sections when cool-down is used.
>
> **Detailed Split Analysis**
> Review every mile or kilometer split in a clean card-style layout with color-coded accent bars highlighting your fastest and slowest segments. Each card shows pace, elevation gain/loss, cadence, and distance — with cool-down splits visually distinguished.
>
> **Cadence Tracking**
> Monitor your steps per minute in real time using your iPhone's built-in motion sensors. No watch or accessory required.
>
> **Route Checkpoints**
> Drop custom checkpoint pins along your named routes during a run. On future runs of the same route, checkpoints are automatically detected as you pass them — with green/red delta badges showing whether you're ahead or behind your benchmark time. Review all checkpoint splits in your run summary.
>
> **Run History & Routes**
> Browse your complete run history with search and filtering. Save frequently-run routes with custom names for easy comparison. View checkpoint pins on route detail maps and manage them with long-press to delete.
>
> **GPX Export**
> Export any run as a standard GPX file to share with other apps or analyze in third-party tools.
>
> **Offline Ready**
> Download map areas in advance for runs in areas with poor signal. Your run data is always recorded locally — no account or internet required.
>
> **Dark Mode**
> Full dark mode support with a muted map style that's easy on the eyes during early morning or evening runs.
>
> Run Tracker stores all data on your device. No account required. No subscriptions. No ads.

### Keywords (100 character limit)

```
running,gps,tracker,pace,cadence,splits,route,checkpoint,cooldown,run
```

### Subtitle (30 character limit)

```
GPS Running & Route Recorder
```

### Promotional Text (170 character limit, can be updated without a new build)

```
Track runs with live GPS, pace splits, cool-down mode, route checkpoints, audio cues, and offline maps. Free, no ads.
```

---

## 5. Screenshots

### Required Device Sizes

Apple requires screenshots for each device size you support. Since the app is iPhone-only:

| Device | Screenshot Size (pixels) | Required |
|--------|-------------------------|----------|
| iPhone 6.9" (iPhone 16 Pro Max) | 1320 × 2868 | Yes (covers 6.5"+ class) |
| iPhone 6.3" (iPhone 16 Pro) | 1206 × 2622 | Recommended |
| iPhone 6.1" (iPhone 16) | 1179 × 2556 | Optional (auto-scaled) |

**Minimum:** 3 screenshots per device size. **Maximum:** 10.
**Format:** PNG or JPEG, no alpha.

### Recommended Screenshot Set (8 screens)

| # | Screen | Content | Key Caption |
|---|--------|---------|-------------|
| 1 | Active Run | Live map with route, pace, distance, and timer visible | "Track Every Step in Real Time" |
| 2 | Pre-Run Countdown | Countdown overlay with large pulsing digit on the map | "Get Set with a Countdown" |
| 3 | Run Summary | Post-run summary with Running/Total dual stat sections | "Detailed Run Summaries" |
| 4 | Splits View | Card-style split table with accent bars for fastest/slowest | "Analyze Every Split" |
| 5 | Cool-Down Mode | Active run with cool-down toggle engaged, Running Only stats | "Separate Your Cool Down" |
| 6 | Checkpoints | Active run with checkpoint pins and delta toast on map | "Set Checkpoints, Beat Your Time" |
| 7 | Run History | History list with search bar, showing multiple past runs | "Your Complete Run History" |
| 8 | Offline Maps | Map download screen or offline indicator | "Run Anywhere, Even Offline" |

### Screenshot Tips

- Use actual app data, not placeholder/mock data — Apple reviewers may check
- Capture on a simulator matching the required resolution or use a real device
- Add device frames and captions using tools like Fastlane Frameit or RocketSim
- Show dark mode variants as additional screenshots (not required, but adds appeal)

---

## 6. URLs

| Field | URL | Required |
|-------|-----|----------|
| **Support URL** | *(must provide — can be a simple GitHub Pages site, support email page, or landing page)* | Yes |
| **Marketing URL** | *(optional — landing page for the app)* | No |
| **Privacy Policy URL** | *(required because the app uses location data)* | Yes |

### Privacy Policy Requirements

The privacy policy must disclose:
- The app collects **precise location data** for run tracking
- The app collects **motion and fitness data** for cadence tracking
- All data is stored **locally on device only** — no data is transmitted to external servers
- No user accounts or personal information are collected
- No third-party analytics or advertising SDKs are included

---

## 7. Age Rating, Pricing & Availability

### Age Rating Questionnaire Answers

| Category | Answer |
|----------|--------|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Prolonged Graphic or Sadistic Violence | None |
| Profanity or Crude Humor | None |
| Mature/Suggestive Themes | None |
| Horror/Fear Themes | None |
| Medical/Treatment Information | None |
| Alcohol, Tobacco, or Drug Use | None |
| Simulated Gambling | None |
| Sexual Content or Nudity | None |
| Unrestricted Web Access | No |
| Gambling with Real Currency | No |

**Expected Rating:** 4+ (suitable for all ages)

### Pricing

| Field | Value |
|-------|-------|
| **Price** | Free |
| **In-App Purchases** | None |
| **Subscriptions** | None |

### Availability

| Field | Value |
|-------|-------|
| **Available in all territories** | Yes |
| **Release option** | Manual release (review first, then release on your schedule) |
| **Pre-order** | No |

---

## 8. Privacy Policy & Permissions

### App Privacy Details (App Store Connect → App Privacy)

Apple requires you to declare data collection practices:

| Data Type | Collected | Linked to User | Used for Tracking |
|-----------|-----------|-----------------|-------------------|
| Precise Location | Yes | No | No |
| Fitness & Exercise | Yes (cadence/steps) | No | No |
| All other categories | No | — | — |

**Data use declaration:** Data is used for **App Functionality** only. Not used for analytics, advertising, or third-party sharing.

### WeatherKit

- The app uses WeatherKit (via entitlement `com.apple.developer.weatherkit`)
- Requires an active Apple Developer Program membership with WeatherKit capability enabled
- No additional privacy disclosure needed for weather data (Apple provides it)

---

## 9. Info.plist Privacy Usage Descriptions

**All required descriptions are already configured in the Xcode build settings (project.pbxproj) for both Debug and Release.**

| Key | Current Value | Status |
|-----|---------------|--------|
| `NSLocationAlwaysAndWhenInUseUsageDescription` | "FreePace needs location access to track your runs even when the screen is locked." | Configured |
| `NSLocationWhenInUseUsageDescription` | "FreePace uses your location to record your running route, distance, and pace in real time." | Configured |
| `NSMotionUsageDescription` | "FreePace uses motion data to track your step cadence during runs." | Configured |

### Background Modes (Info.plist)

| Mode | Reason |
|------|--------|
| `audio` | AVSpeechSynthesizer for audio cues during runs |
| `location` | GPS tracking while screen is locked / app backgrounded |
| `remote-notification` | *(Review if actually used — remove if not needed to avoid review questions)* |

### Action Item

- **Verify `remote-notification` background mode.** If the app does not use push notifications, remove this from `UIBackgroundModes` in Info.plist before submission. Apple may ask why it's declared.

---

## 10. Pre-Submission Checklist

### Assets & Design
- [ ] App icon: 1024×1024 PNG, no alpha, in `AppIcon.appiconset`
- [ ] Launch screen configured (storyboard or Info.plist)
- [ ] Screenshots captured for iPhone 6.9" (minimum)
- [ ] Screenshots captured for iPhone 6.3" (recommended)

### App Store Connect
- [ ] App name, subtitle, bundle ID, and SKU filled in
- [ ] Full description written and proofread
- [ ] Keywords set (100 char max)
- [ ] Promotional text set
- [ ] Primary category: Health & Fitness
- [ ] Support URL live and accessible
- [ ] Privacy Policy URL live and accessible
- [ ] Age rating questionnaire completed
- [ ] Pricing set to Free
- [ ] App Privacy declarations completed (location, motion)

### Xcode & Build
- [ ] All `NS*UsageDescription` keys present for every permission used
- [ ] Remove `remote-notification` from `UIBackgroundModes` if unused
- [ ] Archive built with Release configuration
- [ ] No compiler warnings in Release build
- [ ] Version number and build number set (e.g., 1.0.0 build 1)
- [ ] Deployment target set to iOS 17.0
- [ ] WeatherKit capability enabled in Apple Developer portal
- [ ] App ID and provisioning profile configured for distribution

### Testing Before Submission
- [ ] Test on physical device (not just simulator)
- [ ] Test location permissions flow (first launch → always allow)
- [ ] Test motion permissions flow
- [ ] Test background location tracking (lock screen during run)
- [ ] Test audio cues during a real run
- [ ] Test GPX export and share sheet
- [ ] Test offline map download and usage
- [ ] Test dark mode appearance
- [ ] Test with location services disabled (graceful handling)
- [ ] Test with motion services disabled (graceful handling)
- [ ] Test pre-run countdown (skip and cancel flows)
- [ ] Test cool-down mode toggle and Running Only / Total stat switching
- [ ] Test checkpoint drop during a named-route run and 20-pin cap
- [ ] Test checkpoint detection and benchmark delta display on repeat runs
- [ ] Test checkpoint deletion via long-press on RouteDetailView
- [ ] Run on oldest supported device/iOS version if possible
