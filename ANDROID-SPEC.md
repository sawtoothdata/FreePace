# Android Run Tracker — Full Technical Specification

## Context

Port the existing iOS Run Tracker app (SwiftUI, iOS 17+) to a feature-identical Android app. The iOS app is a fully-featured GPS running tracker with live map display, elevation tracking, split tracking, named routes with coach mode, audio cues, GPX import/export, weather capture, offline map caching, and dark mode support. The Android version should match feature-for-feature.

---

## Technology Stack

| Concern | iOS | Android |
|---|---|---|
| Language | Swift | Kotlin |
| UI | SwiftUI | Jetpack Compose (Material 3) |
| Architecture | MVVM + Services | MVVM + Services + Hilt DI |
| Persistence | SwiftData | Room |
| Preferences | @AppStorage | Jetpack DataStore |
| Maps | MapKit | Google Maps SDK (maps-compose) |
| Location | Core Location | FusedLocationProviderClient (Play Services) |
| Step/Cadence | CMPedometer | SensorManager TYPE_STEP_COUNTER |
| Audio | AVSpeechSynthesizer | Android TextToSpeech |
| Weather | WeatherKit | Open-Meteo API (free, no key) |
| Background | Background Modes | Foreground Service |
| Charts | Swift Charts | Vico (compose-m3) |
| Networking | URLSession | Retrofit + OkHttp |
| GPX Parsing | XMLParser | XmlPullParser |
| Testing | XCTest | JUnit + MockK + Turbine |

---

## Project Structure

```
com.sawtoothdata.runtracker/
├── RunTrackerApplication.kt              // Hilt @HiltAndroidApp
├── MainActivity.kt                       // Single activity, Compose host
├── di/
│   ├── AppModule.kt                      // Room DB, DataStore, OkHttp, Retrofit
│   ├── LocationModule.kt                 // FusedLocationProviderClient
│   └── ServiceModule.kt                  // Service bindings
├── data/
│   ├── db/
│   │   ├── RunTrackerDatabase.kt         // Room database (4 entities)
│   │   ├── Converters.kt                 // Type converters (UUID, etc.)
│   │   ├── dao/
│   │   │   ├── RunDao.kt
│   │   │   ├── SplitDao.kt
│   │   │   ├── RoutePointDao.kt
│   │   │   └── NamedRouteDao.kt
│   │   └── entity/
│   │       ├── RunEntity.kt
│   │       ├── SplitEntity.kt
│   │       ├── RoutePointEntity.kt
│   │       └── NamedRouteEntity.kt
│   ├── repository/
│   │   ├── RunRepository.kt
│   │   └── NamedRouteRepository.kt
│   ├── preferences/
│   │   └── UserPreferences.kt            // DataStore wrapper
│   └── weather/
│       ├── OpenMeteoApi.kt               // Retrofit interface
│       └── OpenMeteoModels.kt            // Response DTOs
├── domain/
│   ├── model/
│   │   ├── Run.kt                        // Domain model
│   │   ├── Split.kt
│   │   ├── RoutePoint.kt
│   │   ├── NamedRoute.kt
│   │   ├── UnitSystem.kt                 // Enum: IMPERIAL, METRIC
│   │   ├── SplitDistance.kt              // Enum: QUARTER, HALF, FULL
│   │   ├── AppearanceMode.kt            // Enum: SYSTEM, LIGHT, DARK
│   │   ├── RunState.kt                   // Enum: IDLE, ACTIVE, PAUSED
│   │   ├── WeatherSnapshot.kt
│   │   ├── SplitSnapshot.kt
│   │   ├── TimeMarker.kt
│   │   ├── BenchmarkSplitMarker.kt
│   │   ├── ElevationProfilePoint.kt
│   │   └── SplitDisplayData.kt
│   └── util/
│       ├── ElevationFilter.kt            // Moving-average smoothing
│       ├── ElevationColor.kt             // Elevation → color gradient
│       ├── SplitTracker.kt               // Split boundary detection
│       └── FormatExtensions.kt           // Double/Date formatting
├── service/
│   ├── location/
│   │   ├── LocationProvider.kt           // Interface
│   │   └── FusedLocationProvider.kt      // Implementation
│   ├── motion/
│   │   ├── MotionProvider.kt             // Interface
│   │   └── StepSensorManager.kt          // Implementation
│   ├── tracking/
│   │   └── RunTrackingService.kt         // Foreground Service (core engine)
│   ├── audio/
│   │   └── AudioCueService.kt            // TextToSpeech wrapper
│   ├── weather/
│   │   └── WeatherService.kt             // Open-Meteo client
│   ├── gpx/
│   │   ├── GpxExportService.kt           // XmlSerializer
│   │   └── GpxImportService.kt           // XmlPullParser
│   ├── map/
│   │   └── MapTileCacheService.kt        // OkHttp cache for OSM tiles
│   └── persistence/
│       └── RunPersistenceService.kt      // Wrapper over repositories
├── ui/
│   ├── navigation/
│   │   └── RunTrackerNavigation.kt       // NavHost + bottom bar
│   ├── theme/
│   │   ├── Theme.kt                      // Material 3 (light/dark/dynamic)
│   │   ├── Color.kt
│   │   └── Type.kt
│   ├── run/
│   │   ├── ActiveRunScreen.kt
│   │   ├── ActiveRunViewModel.kt
│   │   └── components/
│   │       ├── RunMapView.kt
│   │       ├── StatCard.kt
│   │       ├── GpsSignalIndicator.kt
│   │       ├── SplitToastOverlay.kt
│   │       ├── OfflineMapBadge.kt
│   │       └── RouteSelectionSheet.kt
│   ├── history/
│   │   ├── RunHistoryScreen.kt
│   │   ├── RunHistoryViewModel.kt
│   │   ├── FilterSheet.kt
│   │   └── GpxImportPreviewScreen.kt
│   ├── summary/
│   │   ├── RunSummaryScreen.kt
│   │   ├── RunSummaryViewModel.kt
│   │   └── components/
│   │       ├── ElevationProfileChart.kt
│   │       ├── SplitTable.kt
│   │       ├── WeatherDisplay.kt
│   │       ├── RouteMapView.kt
│   │       └── RouteAssignmentSheet.kt
│   ├── settings/
│   │   ├── SettingsScreen.kt
│   │   ├── SettingsViewModel.kt
│   │   └── DownloadMapAreaScreen.kt
│   └── routes/
│       ├── RouteDetailScreen.kt
│       └── RouteComparisonViewModel.kt
└── util/
    ├── PermissionHelper.kt
    └── NotificationHelper.kt
```

---

## Data Models

### Room Entities

```kotlin
@Entity(tableName = "runs")
data class RunEntity(
    @PrimaryKey val id: String,           // UUID string
    val startDate: Long,                  // epoch millis
    val endDate: Long?,
    val distanceMeters: Double,
    val durationSeconds: Double,
    val elevationGainMeters: Double,
    val elevationLossMeters: Double,
    val averagePaceSecondsPerKm: Double?,
    val averageCadence: Double?,
    val totalSteps: Int,
    // Weather (nullable — captured at run start)
    val temperatureCelsius: Double?,
    val feelsLikeCelsius: Double?,
    val humidityPercent: Double?,
    val windSpeedMPS: Double?,
    val weatherCondition: String?,
    val weatherConditionIcon: String?,    // Material icon name
    // Route relationship
    val namedRouteId: String?             // FK, nullable
)

@Entity(
    tableName = "splits",
    foreignKeys = [ForeignKey(
        entity = RunEntity::class,
        parentColumns = ["id"],
        childColumns = ["runId"],
        onDelete = ForeignKey.CASCADE
    )],
    indices = [Index("runId")]
)
data class SplitEntity(
    @PrimaryKey val id: String,
    val runId: String,
    val splitIndex: Int,
    val distanceMeters: Double,
    val durationSeconds: Double,
    val elevationGainMeters: Double,
    val elevationLossMeters: Double,
    val averageCadence: Double?,
    val startDate: Long,
    val endDate: Long,
    val isPartial: Boolean
)

@Entity(
    tableName = "route_points",
    foreignKeys = [ForeignKey(
        entity = RunEntity::class,
        parentColumns = ["id"],
        childColumns = ["runId"],
        onDelete = ForeignKey.CASCADE
    )],
    indices = [Index("runId")]
)
data class RoutePointEntity(
    @PrimaryKey val id: String,
    val runId: String,
    val timestamp: Long,
    val latitude: Double,
    val longitude: Double,
    val altitude: Double,
    val smoothedAltitude: Double,
    val horizontalAccuracy: Float,
    val speed: Float,
    val distanceFromStart: Double,
    val isResumePoint: Boolean
)

@Entity(tableName = "named_routes")
data class NamedRouteEntity(
    @PrimaryKey val id: String,
    val name: String,
    val createdDate: Long,
    val benchmarkRunId: String?
)
```

### Relationship Handling

Room doesn't support SwiftData's declarative cascade/nullify on inverse relationships. Handle NamedRoute deletion manually:

```kotlin
// In NamedRouteRepository
@Transaction
suspend fun deleteNamedRoute(routeId: String) {
    // Nullify namedRouteId on all runs referencing this route
    runDao.clearNamedRouteReferences(routeId)
    // Then delete the route
    namedRouteDao.delete(routeId)
}
```

Splits and RoutePoints cascade-delete automatically via `ForeignKey.CASCADE`.

### Domain Models

Separate from Room entities. Same fields but using Kotlin value types:
- `Run`, `Split`, `RoutePoint`, `NamedRoute` — plain data classes
- Mapping functions: `RunEntity.toDomain()`, `Run.toEntity()`

### Enums (port from iOS SettingsVM.swift)

```kotlin
enum class UnitSystem {
    IMPERIAL, METRIC;
    val metersPerDistanceUnit: Double  // 1609.344 or 1000.0
    val metersPerElevationUnit: Double // 0.3048 or 1.0
    val distanceUnit: String           // "mi" or "km"
    val paceUnit: String               // "/mi" or "/km"
    val elevationUnit: String          // "ft" or "m"
    companion object {
        fun default(): UnitSystem // Locale-based: US/GB/MM/LR → IMPERIAL
    }
}

enum class SplitDistance {
    QUARTER, HALF, FULL;
    fun metersFor(unit: UnitSystem): Double
    fun displayLabel(unit: UnitSystem): String  // "¼ Mi", "½ Km", "1 Mi"
    fun spokenLabel(unit: UnitSystem): String   // "quarter mile", "half kilometer"
}

enum class AppearanceMode { SYSTEM, LIGHT, DARK }
enum class RunState { IDLE, ACTIVE, PAUSED }
enum class TimeMarkerInterval(val minutes: Int) { ONE(1), TWO(2), FIVE(5), TEN(10) }
enum class AudioCueInterval(val minutes: Int) { ONE(1), FIVE(5), TEN(10) }
```

---

## Services — Detailed Specifications

### 1. RunTrackingService (Foreground Service) — THE KEY ANDROID DIFFERENCE

This is the most critical architectural difference from iOS. On iOS, the app uses background modes (location + audio) to keep tracking alive. On Android, a **Foreground Service** with a persistent notification is required.

**The Foreground Service owns the tracking engine.** The ViewModel communicates with it via bound service connection.

```
Architecture:
  ActiveRunViewModel <--bind/StateFlow--> RunTrackingService
                                            ├── FusedLocationProvider
                                            ├── StepSensorManager
                                            ├── SplitTracker
                                            ├── ElevationFilter
                                            ├── AudioCueService (TextToSpeech)
                                            └── Timer (coroutine)
```

**Service responsibilities:**
- Start as foreground service with `FOREGROUND_SERVICE_LOCATION` type
- Show persistent notification: elapsed time, distance, pace (updated every second)
- Own all tracking components (location, motion, splits, elevation, audio)
- Expose `StateFlow<RunTrackingState>` for the ViewModel to observe
- Accept commands: START, PAUSE, RESUME, STOP via Intent actions or binder methods
- On STOP: build final Run domain model, save via RunPersistenceService, broadcast completion

**RunTrackingState:**
```kotlin
data class RunTrackingState(
    val runState: RunState = RunState.IDLE,
    val elapsedSeconds: Long = 0,
    val distanceMeters: Double = 0.0,
    val elevationGainMeters: Double = 0.0,
    val elevationLossMeters: Double = 0.0,
    val currentPaceSecondsPerMeter: Double? = null,
    val currentCadence: Double? = null,
    val totalSteps: Int = 0,
    val routePoints: List<RoutePoint> = emptyList(),
    val latestSplit: SplitSnapshot? = null,
    val currentAccuracy: Float = 0f,
    val currentLocation: LatLng? = null
)
```

**Notification:** Create channel `run_tracking` with importance HIGH. Update notification every second with `NotificationCompat.Builder.setContentText("12:34 • 3.21 mi • 8'15\"/mi")`.

### 2. FusedLocationProvider

**Interface:**
```kotlin
interface LocationProvider {
    val locationFlow: SharedFlow<Location>
    val authorizationFlow: StateFlow<Boolean>
    fun startTracking()
    fun stopTracking()
    fun pauseTracking()   // Stop updates (battery saving)
    fun resumeTracking()  // Restart updates
}
```

**Implementation:**
- `FusedLocationProviderClient` from Play Services
- `LocationRequest`: priority HIGH_ACCURACY, interval 1000ms, fastest interval 500ms
- `LocationCallback` publishes to `MutableSharedFlow<Location>`
- On pause: `removeLocationUpdates()`
- On resume: `requestLocationUpdates()` again

**Thresholds (match iOS):**
- Reject fixes with accuracy > 50m
- Minimum movement: 2m between accepted points
- Speed threshold: 0.3 m/s (below this, pace shows "— —")

### 3. StepSensorManager

**Interface:**
```kotlin
interface MotionProvider {
    val cadenceFlow: StateFlow<Double?>   // steps per minute
    val stepsFlow: StateFlow<Int>         // total steps since run start
    fun startTracking()
    fun stopTracking()
}
```

**Implementation — key difference from iOS:**
- Android `TYPE_STEP_COUNTER` is cumulative since device boot (not per-session like CMPedometer)
- Record baseline at run start: `baselineSteps = sensorEvent.values[0].toInt()`
- Current steps = `latestSteps - baselineSteps`
- **Cadence computation** (iOS provides this; Android does not):
  - Maintain a rolling window of (timestamp, stepCount) samples over last 10 seconds
  - Cadence = (steps in window / seconds in window) * 60
  - Emit `null` if window has < 2 samples
- Register with `SensorManager.registerListener()`, `SENSOR_DELAY_NORMAL`
- Check availability: `sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) != null`

### 4. AudioCueService

**Port from iOS AVSpeechSynthesizer to Android TextToSpeech.**

```kotlin
class AudioCueService @Inject constructor(
    private val context: Context
) {
    private var tts: TextToSpeech? = null
    private var isInitialized = false

    // Configuration (read from UserPreferences)
    var isEnabled: Boolean
    var cueAtSplits: Boolean
    var cueAtTimeIntervals: Boolean
    var timeIntervalMinutes: Int  // 1, 5, or 10
    var isCoachModeEnabled: Boolean

    // Coach data (set by RouteComparisonViewModel)
    var lastRunCumulativeSplitTimes: List<Double>?
    var averageCumulativeSplitTimes: List<Double>?
}
```

**Key differences from iOS:**
- `TextToSpeech` initialization is async — use `TextToSpeech.OnInitListener`
- Audio focus: `AudioManager.requestAudioFocus()` with `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`
- No background task wrapping needed — Foreground Service keeps process alive
- TTS utterance ID tracking via `UtteranceProgressListener` for completion callbacks

**Speech content (match iOS exactly):**
- **Split cue:** "{distance label} {splitIndex}. {duration}. Average pace: {pace}. Last split: {splitPace}."
- **Coach delta (appended if enabled):** "{seconds} seconds ahead/behind your last run." + "{seconds} seconds ahead/behind your average."
- **Time interval cue:** "{elapsed time}. {distance}. Average pace: {pace}."

### 5. WeatherService (Open-Meteo)

**Open-Meteo API** — free, no API key required.

**Endpoint:** `GET https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&temperature_unit=celsius&wind_speed_unit=ms`

**Response mapping:**
```kotlin
data class WeatherSnapshot(
    val temperatureCelsius: Double,
    val feelsLikeCelsius: Double,
    val humidityPercent: Double,     // 0-100 (Open-Meteo gives 0-100, iOS gives 0-1, so divide by 100 for storage)
    val windSpeedMPS: Double,
    val conditionName: String,       // e.g., "Partly Cloudy"
    val conditionIcon: String        // Material icon name
)
```

**WMO Weather Code mapping** (Open-Meteo uses WMO codes):
- 0: Clear → "Clear", `Icons.Default.WbSunny`
- 1-3: Partly/Mostly Cloudy → `Icons.Default.Cloud`
- 45, 48: Fog → `Icons.Default.Foggy`
- 51-57: Drizzle → `Icons.Default.Grain`
- 61-67: Rain → `Icons.Default.WaterDrop`
- 71-77: Snow → `Icons.Default.AcUnit`
- 80-82: Rain showers → `Icons.Default.Thunderstorm`
- 85-86: Snow showers → `Icons.Default.Snowing`
- 95, 96, 99: Thunderstorm → `Icons.Default.Thunderstorm`

**Implementation:** Retrofit interface, called once at run start, returns null on failure.

### 6. SplitTracker (Direct Port)

Pure logic — ports directly from iOS with minimal changes.

- Replace `PassthroughSubject<SplitSnapshot>` with `MutableSharedFlow<SplitSnapshot>`
- Same split boundary detection logic
- Same cadence weighted averaging
- Same partial final split on run end
- Same `changeUnitSystem()` recalculation

### 7. ElevationFilter (Direct Port)

Pure logic — direct port.
- 5-sample moving average window
- ±0.5m dead zone
- Cumulative gain/loss from smoothed values

### 8. GpxExportService

- Use `XmlSerializer` (Android built-in) instead of string concatenation
- Same GPX 1.1 format with ISO8601 timestamps
- Same pause-aware `<trkseg>` segmentation
- Write to app cache dir: `context.cacheDir`
- Share via `FileProvider` + `Intent.ACTION_SEND`
- Bulk export: `Intent.ACTION_SEND_MULTIPLE` with multiple URIs

### 9. GpxImportService

- Use `XmlPullParser` (Android built-in) instead of XMLParser delegate
- Same parsing logic: extract `<trkpt>` lat/lon/ele/time, group by `<trkseg>`
- File picker: `ActivityResultContracts.OpenDocument` with MIME types `["application/gpx+xml", "application/xml", "text/xml"]`
- Same stats computation using ElevationFilter and SplitTracker

### 10. MapTileCacheService

- Use `OkHttp Cache` (500MB disk) instead of URLCache
- Same tile URL enumeration: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`
- Same zoom levels 10-16
- Same bounding box calculation with 10% padding
- For rendering: use Google Maps `TileOverlay` with custom `TileProvider` that reads from cache
- Same `formattedCacheSize` via Formatter
- Same `clearCache()` functionality

---

## Screens & Navigation

### Navigation Structure

```
MainActivity (single Activity)
└── NavHost with BottomNavigationBar
    ├── Tab 1: "Run" → ActiveRunScreen
    │   └── → RunSummaryScreen (on run completion)
    │       └── → RouteDetailScreen (on route tap)
    │           └── → RunSummaryScreen (individual runs)
    ├── Tab 2: "History" → RunHistoryScreen
    │   ├── → RunSummaryScreen (on run tap)
    │   └── → GpxImportPreviewScreen (on file import)
    └── Tab 3: "Settings" → SettingsScreen
        └── → DownloadMapAreaScreen
```

Bottom bar icons: `Icons.Default.DirectionsRun`, `Icons.Default.History`, `Icons.Default.Settings`

### Screen Specifications

#### ActiveRunScreen

**Idle State:**
- Google Map centered on user location (tight zoom ~16)
- GPS signal indicator (top-left overlay)
- Large green "Start" circular button (bottom center)
- Last run summary card (below map, if exists): date, distance, duration, pace
- Route selection button (top-right, if named routes exist) → opens RouteSelectionSheet

**Active State:**
- Map (top ~55%):
  - User location marker
  - Elevation-colored polyline (green→yellow→orange→brown)
  - Time markers at configured intervals (circle + time label)
  - Named route overlay (dashed gray, 30% opacity) if running named route
  - Benchmark split markers (white circles with index + time)
  - Zoom +/- buttons, re-center button (appears when user pans, auto-hides after 5s)
  - Map style toggle (standard/hybrid)
  - Offline badge (when no connectivity)
  - Runner view / route view toggle (when on named route)
- Stats dashboard (bottom ~45%):
  - Elapsed time (largest, monospaced, top center)
  - 2-column grid: distance, current pace, elevation gain, elevation loss, cadence
  - All displayed via StatCard composable
- Controls: Pause button (center), Stop button (with confirmation AlertDialog)
- Split toast (top overlay): appears on split completion, auto-dismisses after 5s
  - Shows: split index, split duration, coach delta (+/-MM:SS in green/red)

**Paused State:**
- Same map (frozen)
- Pulsing elapsed time with amber tint, "PAUSED" label
- Resume button, Stop button

**Coach mode badge:** Toggle button visible when named route selected and has prior runs.

#### RunSummaryScreen

- Header: date (`runDateTimeDisplay`), time of day label, route name if assigned
- Stat cards (2x2 grid): distance, duration, avg pace, cadence
- Elevation row: gain ↑, loss ↓, total steps
- Weather section (if data): condition icon, temperature, feels-like, humidity, wind
- Route map: fitted polyline (elevation-colored), start pin (green), finish pin (red), time markers
- Elevation profile chart: Vico area + line chart, x=distance, y=elevation
- Splits table: columns = #, time, pace, elev↑, elev↓, cadence
  - Row colors: green background (fastest), red background (slowest), italic text (partial)
- Action buttons (3 circular, bottom):
  - Name/assign route → RouteAssignmentSheet
  - Export GPX → share intent
  - Delete → confirmation dialog

#### RunHistoryScreen

- `LazyColumn` of run cards: date, route name, distance, duration, pace, weather icon
- Sort/filter button (toolbar) → FilterSheet (ModalBottomSheet):
  - Sort by: date, distance, duration, pace (ascending/descending)
  - Date range filter (date pickers)
  - Min distance filter (text field)
  - Named route filter (dropdown)
  - Clear filters button
- GPX import button (toolbar) → file picker → GpxImportPreviewScreen
- Swipe-to-delete with confirmation
- Empty state: illustration + "Lace up and hit Start!"
- Tap run → navigate to RunSummaryScreen

#### SettingsScreen

- **Units section:** Imperial/Metric segmented button row, split distance picker
- **Map section:** Time marker interval picker
- **Audio Cues section:** Enable toggle, cue at splits toggle, cue at time intervals toggle + interval picker
- **Appearance section:** System/Light/Dark segmented button row
- **Data section:** "Export All Runs" button (share intent with multiple GPX files)
- **Offline Maps section:** Cache size display, "Clear Cache" button with confirmation

#### RouteDetailScreen

- Header: route name, run count
- Route map (60%): fitted green polyline, start/finish pins, benchmark split markers with labels and times
- Timing stats: best time, average time, last run time
- Benchmark splits table (reuses SplitTable)
- Pace trend chart: Vico line chart (if 2+ runs) showing pace improvement over time
- Runs list: all runs on this route, navigate to summary
- Actions: rename (dialog with text field), delete (confirmation, unlinks runs)

#### DownloadMapAreaScreen

- Full-screen Google Map for area selection
- "Download This Area" button (bottom)
- Progress bar during download
- Cancel button

#### GpxImportPreviewScreen

- Parsed GPX preview: date/time, distance, duration, pace, elevation
- Route map preview
- Import / Cancel buttons

---

## Permissions

Request at appropriate times (not all at once on first launch):

| Permission | When | Required For |
|---|---|---|
| `ACCESS_FINE_LOCATION` | Before first run start | GPS tracking |
| `ACCESS_COARSE_LOCATION` | Before first run start | Fallback location |
| `ACCESS_BACKGROUND_LOCATION` | After fine location granted | Foreground service location type |
| `FOREGROUND_SERVICE` | Manifest only | Foreground service |
| `FOREGROUND_SERVICE_LOCATION` | Manifest only | Location foreground service type |
| `POST_NOTIFICATIONS` | Before first run (Android 13+) | Foreground service notification |
| `ACTIVITY_RECOGNITION` | Before first run (Android 10+) | Step counter |
| `INTERNET` | Manifest only | Weather, map tiles |

**Flow:** On first "Start" tap, check and request `ACCESS_FINE_LOCATION` + `ACTIVITY_RECOGNITION` + `POST_NOTIFICATIONS`. If granted, request `ACCESS_BACKGROUND_LOCATION` separately (Android requires this as a separate step). Only then start the run.

---

## AndroidManifest Declarations

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
<uses-permission android:name="android.permission.INTERNET" />

<application ...>
    <service
        android:name=".service.tracking.RunTrackingService"
        android:foregroundServiceType="location"
        android:exported="false" />

    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="${MAPS_API_KEY}" />
</application>
```

---

## Dependencies (build.gradle.kts)

```kotlin
// Core
implementation("androidx.core:core-ktx:1.13.0")
implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.0")
implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.0")
implementation("androidx.activity:activity-compose:1.9.0")

// Compose + Material 3
implementation(platform("androidx.compose:compose-bom:2024.06.00"))
implementation("androidx.compose.material3:material3")
implementation("androidx.compose.material:material-icons-extended")
implementation("androidx.navigation:navigation-compose:2.8.0")

// Hilt DI
implementation("com.google.dagger:hilt-android:2.51")
kapt("com.google.dagger:hilt-compiler:2.51")
implementation("androidx.hilt:hilt-navigation-compose:1.2.0")

// Room
implementation("androidx.room:room-runtime:2.6.1")
implementation("androidx.room:room-ktx:2.6.1")
kapt("androidx.room:room-compiler:2.6.1")

// DataStore
implementation("androidx.datastore:datastore-preferences:1.1.1")

// Google Maps
implementation("com.google.maps.android:maps-compose:6.1.0")
implementation("com.google.android.gms:play-services-maps:19.0.0")
implementation("com.google.android.gms:play-services-location:21.3.0")

// Networking (Open-Meteo weather)
implementation("com.squareup.retrofit2:retrofit:2.11.0")
implementation("com.squareup.retrofit2:converter-moshi:2.11.0")
implementation("com.squareup.moshi:moshi-kotlin:1.15.1")
implementation("com.squareup.okhttp3:okhttp:4.12.0")

// Charts
implementation("com.patrykandpatrick.vico:compose-m3:2.0.0-alpha.19")

// Coroutines
implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")

// Testing
testImplementation("junit:junit:4.13.2")
testImplementation("io.mockk:mockk:1.13.11")
testImplementation("app.cash.turbine:turbine:1.1.0")
testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
testImplementation("androidx.room:room-testing:2.6.1")
androidTestImplementation("androidx.compose.ui:ui-test-junit4")
```

---

## Phased Implementation Plan

### Phase 1: Project Scaffolding & Data Layer

1. Create Android project (Compose Activity template, min SDK 26, target SDK 34)
2. Add all dependencies to build.gradle.kts
3. Set up Hilt: `RunTrackerApplication`, `AppModule`, `@HiltAndroidApp`
4. Implement Room entities (RunEntity, SplitEntity, RoutePointEntity, NamedRouteEntity)
5. Implement Room DAOs with queries
6. Implement `RunTrackerDatabase` with all entities
7. Implement domain models and entity ↔ domain mappers
8. Implement `UnitSystem`, `SplitDistance`, `AppearanceMode`, `RunState` enums
9. Implement `UserPreferences` with DataStore
10. Implement `RunRepository` and `NamedRouteRepository`
11. Implement `FormatExtensions.kt` (all formatting from `Double+Formatting.swift` and `Date+Formatting.swift`)
12. Set up Material 3 theme (light, dark, muted map style JSON)
13. Set up navigation scaffold: `MainActivity` + `RunTrackerNavigation` with 3 tabs

**Verification:** App builds, shows 3 empty tabs, light/dark theme works.

### Phase 2: Location, Motion & Tracking Engine

1. Implement `LocationProvider` interface
2. Implement `FusedLocationProvider` with `LocationRequest` and `LocationCallback`
3. Implement `MotionProvider` interface
4. Implement `StepSensorManager` with cadence computation (rolling 10s window)
5. Implement `ElevationFilter` (direct port from iOS)
6. Implement `SplitTracker` with `SharedFlow` (direct port, replace `PassthroughSubject`)
7. Implement `NotificationHelper` (create channel, build notification)
8. Implement `PermissionHelper` (runtime permission flow)
9. Implement `RunTrackingService` (Foreground Service):
   - Service lifecycle (start/stop foreground)
   - Location subscription and distance accumulation
   - Timer coroutine (1Hz)
   - Step sensor subscription
   - Split tracking integration
   - Elevation filtering
   - Notification updates (every second)
   - `StateFlow<RunTrackingState>` exposure
   - Command handling (START, PAUSE, RESUME, STOP)
10. Implement `ActiveRunViewModel`:
    - Bind to `RunTrackingService`
    - Expose UI state from service's `StateFlow`
    - Pace calculation (rolling 15s window, recalc every 5s)
    - Start/pause/resume/stop commands
    - Keep screen on: `WindowCompat` / `FLAG_KEEP_SCREEN_ON`

**Verification:** Start a run, see timer ticking, location updates flowing, notification visible. Backgrounding keeps tracking alive.

### Phase 3: Active Run UI

1. Implement `StatCard` composable
2. Implement `GpsSignalIndicator` composable (3-level: green ≤10m, yellow ≤30m, orange ≤50m, red >50m)
3. Implement `RunMapView` with Google Maps Compose:
   - User location marker
   - Polyline rendering
   - Camera following user
4. Implement `ElevationColor` (direct port — return `androidx.compose.ui.graphics.Color`)
5. Implement elevation-colored polyline segments (multiple `Polyline` composables)
6. Implement time markers on map (circle `Marker` + time label)
7. Implement `ActiveRunScreen`:
   - Idle state: map, start button, GPS indicator, last run card
   - Active state: map (top), stats grid (bottom), pause/stop buttons
   - Paused state: pulsing timer, amber tint, resume/stop
8. Implement `SplitToastOverlay` with animation (`AnimatedVisibility`, slide from top)
9. Implement stop confirmation `AlertDialog`
10. Implement map controls: zoom, re-center, style toggle
11. Implement runner view / route view toggle

**Verification:** Full active run UI with live map, stats, split toasts, all controls working.

### Phase 4: Persistence, History & Summary

1. Implement `RunPersistenceService` (save completed runs with splits + route points)
2. Wire run completion: service builds Run → saves → ViewModel navigates to summary
3. Implement `RunSummaryViewModel` (formatted display strings, split data, elevation profile)
4. Implement `SplitTable` composable (fastest green, slowest red, partial italic)
5. Implement `ElevationProfileChart` with Vico (area + line marks)
6. Implement `RunSummaryScreen` (stat cards, map, elevation chart, splits, action buttons)
7. Implement `RunHistoryViewModel` (fetch, sort, filter via Room queries)
8. Implement `FilterSheet` (ModalBottomSheet with sort/filter controls)
9. Implement `RunHistoryScreen` (LazyColumn, swipe-to-delete, empty state)
10. Implement last run summary card on idle screen
11. Wire delete action with confirmation

**Verification:** Complete run lifecycle: start → track → stop → view summary → see in history.

### Phase 5: Named Routes & Coach Mode

1. Implement named route CRUD in `NamedRouteRepository`
2. Implement `RouteAssignmentSheet` (create new route or assign to existing)
3. Implement `RouteSelectionSheet` (free run vs named route, coach mode toggle)
4. Implement `RouteComparisonViewModel`:
   - Load benchmark run (benchmarkRunId or best pace)
   - Build benchmark split markers
   - Compute pace comparison delta
   - Load coach data (last run + average cumulative split times)
5. Wire route selection into `ActiveRunViewModel`
6. Implement benchmark route overlay on map (dashed polyline)
7. Implement benchmark split markers on map
8. Implement pace delta display on split toast (+/-MM:SS)
9. Implement `RouteDetailScreen` (map, timing stats, pace trend chart, runs list, rename/delete)

**Verification:** Create route from completed run, select it before next run, see overlay and coach comparisons.

### Phase 6: Audio Cues

1. Implement `AudioCueService`:
   - TextToSpeech initialization with `OnInitListener`
   - Audio focus management (`requestAudioFocus` with duck)
   - Split cue formatting and speaking
   - Time interval cue formatting and speaking
   - Coach mode delta announcements
   - `UtteranceProgressListener` for completion tracking
2. Wire `AudioCueService` into `RunTrackingService`
3. Wire configuration from `UserPreferences`

**Verification:** Audio cues fire at splits and time intervals. Coach mode announces deltas. Audio ducks other media.

### Phase 7: GPX Import/Export

1. Implement `GpxExportService` with `XmlSerializer`
2. Set up `FileProvider` in manifest for sharing
3. Implement GPX share from RunSummaryScreen
4. Implement bulk export from SettingsScreen
5. Implement `GpxImportService` with `XmlPullParser`
6. Implement `GpxImportPreviewScreen` (stats, map, import/cancel)
7. Wire file picker in RunHistoryScreen toolbar

**Verification:** Export run as GPX, open in another app. Import GPX file, preview, save.

### Phase 8: Weather

1. Implement `OpenMeteoApi` Retrofit interface
2. Implement `WeatherService` with WMO code → condition name/icon mapping
3. Wire weather fetch at run start in `RunTrackingService`
4. Store weather data on Run
5. Implement `WeatherDisplay` composable in RunSummaryScreen

**Verification:** Start run → weather captured → visible in run summary.

### Phase 9: Offline Maps, Settings & Polish

1. Implement `MapTileCacheService` with OkHttp cache
2. Implement custom `TileProvider` for Google Maps overlay
3. Implement `DownloadMapAreaScreen`
4. Implement `OfflineMapBadge` (network connectivity monitor)
5. Implement `SettingsScreen` with all preference controls
6. Implement appearance mode with dynamic Material 3 theming
7. Wire all preferences to their respective services/viewmodels

**Verification:** All settings persist and take effect. Map tiles cached for offline use.

### Phase 10: Testing

1. Unit tests: `ElevationFilter`, `SplitTracker`, `FormatExtensions`, `ElevationColor`
2. Unit tests: `GpxExportService`, `GpxImportService`
3. Unit tests: `AudioCueService` coach comparison text generation
4. ViewModel tests with MockK (fake repositories, fake providers)
5. Room DAO integration tests (in-memory database)
6. Compose UI tests for key screens
7. Edge cases: no GPS, permissions denied, TTS init failure, no network

---

## iOS → Android File Mapping Reference

| iOS File | Android File | Port Complexity |
|---|---|---|
| `Run_TrackerApp.swift` | `MainActivity.kt` + `RunTrackerNavigation.kt` | Medium |
| `Run.swift` | `RunEntity.kt` + `Run.kt` | Low |
| `Split.swift` | `SplitEntity.kt` + `Split.kt` | Low |
| `RoutePoint.swift` | `RoutePointEntity.kt` + `RoutePoint.kt` | Low |
| `NamedRoute.swift` | `NamedRouteEntity.kt` + `NamedRoute.kt` | Low |
| `UnitSystem.swift` | `UnitSystem.kt` | Low (direct port) |
| `LocationManager.swift` | `FusedLocationProvider.kt` | Medium |
| `MotionManager.swift` | `StepSensorManager.kt` | Medium (cadence computation) |
| `AudioCueService.swift` | `AudioCueService.kt` | Medium (TTS + AudioFocus) |
| `SplitTracker.swift` | `SplitTracker.kt` | Low (direct port) |
| `ElevationFilter.swift` | `ElevationFilter.kt` | Low (direct port) |
| `WeatherService.swift` | `WeatherService.kt` + `OpenMeteoApi.kt` | Medium (new API) |
| `RunPersistenceService.swift` | `RunPersistenceService.kt` + DAOs | Medium |
| `GPXExportService.swift` | `GpxExportService.kt` | Low |
| `GPXImportService.swift` | `GpxImportService.kt` | Low |
| `MapTileCacheService.swift` | `MapTileCacheService.kt` | Medium |
| `ActiveRunVM.swift` | `ActiveRunViewModel.kt` + `RunTrackingService.kt` | **High** (split into 2) |
| `RunSummaryVM.swift` | `RunSummaryViewModel.kt` | Low |
| `RunHistoryVM.swift` | `RunHistoryViewModel.kt` | Low |
| `RouteComparisonVM.swift` | `RouteComparisonViewModel.kt` | Low |
| `SettingsVM.swift` | `SettingsViewModel.kt` + enums | Low |
| `ActiveRunView.swift` | `ActiveRunScreen.kt` + `RunMapView.kt` | **High** (Maps Compose) |
| `RunSummaryView.swift` | `RunSummaryScreen.kt` + components | Medium |
| `RunHistoryListView.swift` | `RunHistoryScreen.kt` | Medium |
| `SettingsView.swift` | `SettingsScreen.kt` | Low |
| `RouteDetailView.swift` | `RouteDetailScreen.kt` | Medium |
| `DownloadMapAreaView.swift` | `DownloadMapAreaScreen.kt` | Low |
| `GPXImportPreviewView.swift` | `GpxImportPreviewScreen.kt` | Low |
| `Double+Formatting.swift` | `FormatExtensions.kt` | Low |
| `Date+Formatting.swift` | `FormatExtensions.kt` | Low |
| `ElevationColor.swift` | `ElevationColor.kt` | Low |
| All components | Corresponding composables | Low-Medium |

---

## Key Constants (Match iOS)

```kotlin
// Location thresholds
const val MIN_MOVEMENT_METERS = 2.0
const val MAX_ACCEPTABLE_ACCURACY_METERS = 50.0
const val SLOW_SPEED_THRESHOLD_MPS = 0.3

// Pace calculation
const val PACE_WINDOW_SECONDS = 15L
const val PACE_RECALC_INTERVAL_SECONDS = 5L

// Elevation filter
const val ELEVATION_WINDOW_SIZE = 5
const val ELEVATION_DEAD_ZONE_METERS = 0.5

// Polyline update
const val POLYLINE_UPDATE_INTERVAL_SECONDS = 1L

// Split toast
const val SPLIT_TOAST_DURATION_MS = 5000L

// Map tile cache
const val MAP_CACHE_SIZE_BYTES = 500L * 1024L * 1024L  // 500 MB
const val MAP_CACHE_MEMORY_SIZE = 50L * 1024L * 1024L   // 50 MB
const val MAP_TILE_MIN_ZOOM = 10
const val MAP_TILE_MAX_ZOOM = 16

// Unit conversions
const val METERS_PER_MILE = 1609.344
const val METERS_PER_KM = 1000.0
const val METERS_PER_FOOT = 0.3048
```

---

## Key Platform Differences Summary

| Concern | iOS Approach | Android Approach |
|---|---|---|
| Background tracking | Background modes (location + audio) | Foreground Service with notification |
| Tracking engine lives in | ViewModel (ActiveRunVM) | Foreground Service (RunTrackingService) |
| Reactive streams | Combine (PassthroughSubject, CurrentValueSubject) | Kotlin Flow (SharedFlow, StateFlow) |
| Dependency injection | Manual (protocol-based) | Hilt (@Inject, @HiltViewModel) |
| Step cadence | CMPedometer provides directly | Compute from step deltas over rolling window |
| Text-to-speech | AVSpeechSynthesizer (sync init) | TextToSpeech (async init via OnInitListener) |
| Audio session | AVAudioSession (.playback, .duckOthers) | AudioManager.requestAudioFocus (DUCK) |
| Weather | WeatherKit (Apple, free) | Open-Meteo (free, no API key) |
| Map SDK | MapKit (native) | Google Maps SDK (requires API key) |
| Icons | SF Symbols | Material Icons |
| Preferences | @AppStorage (UserDefaults) | Jetpack DataStore |
| Data persistence | SwiftData (@Model, @Relationship) | Room (@Entity, ForeignKey, DAO) |
| File sharing | UIActivityViewController | Intent.ACTION_SEND + FileProvider |
| File picking | .fileImporter modifier | ActivityResultContracts.OpenDocument |
| Permissions | Info.plist + requestAlwaysAuthorization | Manifest + runtime requestPermission |
| Charts | Swift Charts | Vico |
| Observable pattern | @Observable macro (iOS 17) | StateFlow + collectAsState() |
