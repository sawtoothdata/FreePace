//
//  ActiveRunVM.swift
//  Run-Tracker
//

import Foundation
import CoreLocation
import Combine
import UIKit

/// A time marker dropped on the map at a configured interval
struct TimeMarker: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let elapsedSeconds: Double
    let formattedTime: String
}

enum RunState {
    case idle
    case countdown
    case active
    case paused
}

@Observable
final class ActiveRunVM {
    // MARK: - Published State

    private(set) var runState: RunState = .idle
    private(set) var elapsedSeconds: Double = 0
    private(set) var totalDistanceMeters: Double = 0
    private(set) var elevationGainMeters: Double = 0
    private(set) var elevationLossMeters: Double = 0
    private(set) var currentPaceSecondsPerMeter: Double = 0
    private(set) var currentCadence: Double?
    private(set) var totalSteps: Int = 0
    private(set) var displayedRouteCoordinates: [CLLocationCoordinate2D] = []
    private(set) var elevationRouteSegments: [ElevationRouteSegment] = []
    private(set) var elevationRange: (min: Double, max: Double) = (0, 0)
    private(set) var paceRouteSegments: [ElevationRouteSegment] = []
    private(set) var paceRange: (min: Double, max: Double) = (0, 0)
    private(set) var timeMarkers: [TimeMarker] = []
    private(set) var latestSplit: SplitSnapshot?
    private(set) var currentHorizontalAccuracy: Double = -1
    private(set) var currentUserLocation: CLLocation?
    private(set) var completedRun: Run?
    var isCoolDownActive: Bool = false
    private(set) var activeNamedRoute: NamedRoute?
    private(set) var namedRouteCoordinates: [CLLocationCoordinate2D] = []
    let routeComparison = RouteComparisonVM()
    private var collectedSplits: [SplitSnapshot] = []
    private var weatherSnapshot: WeatherSnapshot?
    private var weatherFetchTask: Task<Void, Never>?
    private var coolDownDistanceAccumMeters: Double = 0
    private var coolDownDurationAccumSeconds: Double = 0
    private(set) var hadCoolDownDuringRun: Bool = false
    private var timeToFirstWalkSeconds: Double?

    // MARK: - Checkpoint State
    private(set) var routeCheckpoints: [RouteCheckpoint] = []
    private(set) var nextCheckpointIndex: Int = 0
    private var benchmarkCheckpointResults: [LapCheckpointKey: Double] = [:]
    private var averageCheckpointResults: [LapCheckpointKey: Double] = [:]
    var latestCheckpointResult: (result: RunCheckpointResult, delta: Double?)?
    private(set) var checkpointResultCounter: Int = 0
    var latestCheckpointWasManualDrop: Bool = false
    private var pendingCheckpointResults: [RunCheckpointResult] = []
    /// Tracks the closest distance to the next checkpoint while approaching it
    private var closestDistanceToNextCheckpoint: Double = .greatestFiniteMagnitude
    /// The location at the closest approach point
    private var closestApproachLocation: CLLocation?

    // MARK: - Lap State
    private(set) var currentLap: Int = 0
    private(set) var isLoopRoute: Bool = false
    private(set) var lapStartElapsedSeconds: Double = 0
    private(set) var lapStartDistanceMeters: Double = 0
    private(set) var lapTimes: [Double] = []

    /// Composite key for benchmark/average lookups that includes lap number.
    struct LapCheckpointKey: Hashable {
        let checkpointID: UUID
        let lap: Int
    }

    /// Checkpoints dropped during a free run (no named route selected)
    private(set) var pendingFreeRunCheckpoints: [RouteCheckpoint] = []

    /// Route selected before starting (for auto-assignment on completion)
    var selectedNamedRoute: NamedRoute?

    /// Coach mode: compare current run to last run and average on the route
    var isCoachModeEnabled: Bool = false

    // MARK: - Dependencies

    private let locationProvider: LocationProviding
    private let motionProvider: MotionProviding
    private(set) var splitTracker: SplitTracker
    private var elevationFilter = ElevationFilter()
    let audioCueService = AudioCueService()

    // MARK: - Countdown State

    var countdownSeconds: Int = 10
    private var countdownCancellable: AnyCancellable?

    // MARK: - Internal State

    private var cancellables = Set<AnyCancellable>()
    private var timerCancellable: AnyCancellable?
    private var previousLocation: CLLocation?
    private var isResumePoint = false
    private var routePoints: [(location: CLLocation, distanceFromStart: Double, smoothedAltitude: Double?, timestamp: Date)] = []
    private var lastPolylineUpdateTime: Date?
    private var lastPaceRecalcTime: Date?
    private var startDate: Date?
    private var nextTimeMarkerSeconds: Double = 0

    // MARK: - Configuration

    private let unitSystem: UnitSystem
    private let splitDistanceSetting: SplitDistance
    private let minimumMovementThreshold: Double = 2.0 // meters
    private let maximumAccuracy: Double = 50.0 // meters - reject fixes worse than this
    private let slowSpeedThreshold: Double = 0.3 // m/s
    private let paceWindowDuration: Double = 15.0 // seconds
    private let paceRecalcInterval: Double = 5.0 // seconds
    private let polylineUpdateInterval: TimeInterval = 1.0
    private let timeMarkersEnabled: Bool
    private let timeMarkerIntervalMinutes: Int

    init(
        locationProvider: LocationProviding,
        motionProvider: MotionProviding,
        unitSystem: UnitSystem = .imperial,
        splitDistance: SplitDistance = .full,
        timeMarkersEnabled: Bool = false,
        timeMarkerIntervalMinutes: Int = 5
    ) {
        self.locationProvider = locationProvider
        self.motionProvider = motionProvider
        self.unitSystem = unitSystem
        self.splitDistanceSetting = splitDistance
        self.timeMarkersEnabled = timeMarkersEnabled
        self.timeMarkerIntervalMinutes = timeMarkerIntervalMinutes
        self.splitTracker = SplitTracker(unitSystem: unitSystem, splitDistance: splitDistance)
    }

    // MARK: - Initialization

    private var idleLocationCancellable: AnyCancellable?

    /// Start receiving location updates for the idle screen (GPS indicator, map centering)
    func initializeLocation() {
        guard runState == .idle || runState == .countdown, idleLocationCancellable == nil else { return }
        idleLocationCancellable = locationProvider.locationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.currentHorizontalAccuracy = location.horizontalAccuracy
                self?.currentUserLocation = location
            }
        locationProvider.startTracking()
    }

    private func stopIdleLocation() {
        idleLocationCancellable?.cancel()
        idleLocationCancellable = nil
    }

    /// Stop location updates when the idle view disappears (tab switch).
    /// Does nothing if a run is active or paused — background tracking must continue.
    func pauseIdleLocationIfNotRunning() {
        guard runState == .idle else { return }
        stopIdleLocation()
        locationProvider.stopTracking()
    }

    // MARK: - Countdown

    func startCountdown() {
        guard runState == .idle else { return }
        runState = .countdown
        countdownSeconds = 10

        // Start GPS acquisition during countdown
        locationProvider.startTracking()

        countdownCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.runState == .countdown else { return }
                self.countdownSeconds -= 1
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if self.countdownSeconds <= 0 {
                    self.startRunNow()
                }
            }
    }

    func cancelCountdown() {
        countdownCancellable?.cancel()
        countdownCancellable = nil
        locationProvider.stopTracking()
        runState = .idle
        countdownSeconds = 10
    }

    // MARK: - Actions

    func startRun() {
        startCountdown()
    }

    func startRunNow() {
        // Cancel countdown timer if coming from countdown
        countdownCancellable?.cancel()
        countdownCancellable = nil

        guard runState == .idle || runState == .countdown else { return }
        runState = .active
        elapsedSeconds = 0
        totalDistanceMeters = 0
        elevationGainMeters = 0
        elevationLossMeters = 0
        currentPaceSecondsPerMeter = 0
        currentCadence = nil
        totalSteps = 0
        displayedRouteCoordinates = []
        latestSplit = nil
        completedRun = nil
        collectedSplits = []
        weatherFetchTask?.cancel()
        weatherFetchTask = nil
        weatherSnapshot = nil
        isCoolDownActive = false
        coolDownDistanceAccumMeters = 0
        coolDownDurationAccumSeconds = 0
        hadCoolDownDuringRun = false
        timeToFirstWalkSeconds = nil
        pendingCheckpointResults = []
        pendingFreeRunCheckpoints = []
        nextCheckpointIndex = 0
        benchmarkCheckpointResults = [:]
        averageCheckpointResults = [:]
        latestCheckpointResult = nil
        closestDistanceToNextCheckpoint = .greatestFiniteMagnitude
        closestApproachLocation = nil
        currentLap = 0
        lapTimes = []
        lapStartElapsedSeconds = 0
        lapStartDistanceMeters = 0
        isLoopRoute = false

        // Load checkpoints from named route
        if let route = selectedNamedRoute {
            routeCheckpoints = route.checkpoints.sorted { $0.order < $1.order }

            // Detect loop route
            isLoopRoute = route.isLoopRoute || detectLoopRoute(route: route)

            if let benchmarkRunID = route.benchmarkRunID {
                let benchmarkRun = route.runs.first { $0.id == benchmarkRunID }
                if let results = benchmarkRun?.checkpointResults {
                    for result in results {
                        if let cp = result.checkpoint {
                            let key = LapCheckpointKey(checkpointID: cp.id, lap: result.lapNumber)
                            benchmarkCheckpointResults[key] = result.elapsedSeconds
                        }
                    }
                }
            }

            // Compute average elapsed time per checkpoint+lap across all prior runs
            var sums: [LapCheckpointKey: Double] = [:]
            var counts: [LapCheckpointKey: Int] = [:]
            for run in route.runs {
                for result in run.checkpointResults {
                    if let cp = result.checkpoint {
                        let key = LapCheckpointKey(checkpointID: cp.id, lap: result.lapNumber)
                        sums[key, default: 0] += result.elapsedSeconds
                        counts[key, default: 0] += 1
                    }
                }
            }
            for (key, total) in sums {
                if let count = counts[key], count > 0 {
                    averageCheckpointResults[key] = total / Double(count)
                }
            }
        } else {
            routeCheckpoints = []
        }

        previousLocation = nil
        routePoints = []
        timeMarkers = []
        elevationFilter.reset()
        nextTimeMarkerSeconds = Double(timeMarkerIntervalMinutes * 60)

        let now = Date()
        startDate = now
        splitTracker = SplitTracker(unitSystem: unitSystem, splitDistance: splitDistanceSetting, startDate: now)
        lastPolylineUpdateTime = now
        lastPaceRecalcTime = now
        isResumePoint = false

        // Keep screen on during active run
        UIApplication.shared.isIdleTimerDisabled = true

        stopIdleLocation()
        startTimer()
        subscribeToLocation()
        subscribeToMotion()
        subscribeToSplits()

        locationProvider.startTracking()
        motionProvider.startCadenceUpdates(from: now)

        // Fetch weather at run start, retrying until location is available
        weatherFetchTask = Task { [weak self] in
            guard let self else { return }

            // Wait up to 15 seconds for a location fix if not yet available
            var location = self.currentUserLocation
            if location == nil {
                for _ in 0..<30 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if Task.isCancelled { return }
                    location = await MainActor.run { self.currentUserLocation }
                    if location != nil { break }
                }
            }

            if let location {
                let snapshot = await RunWeatherService.shared.fetchCurrentWeather(for: location)
                await MainActor.run {
                    if self.weatherSnapshot == nil {
                        self.weatherSnapshot = snapshot
                    }
                }
            }

            #if targetEnvironment(simulator)
            await MainActor.run {
                if self.weatherSnapshot == nil {
                    self.weatherSnapshot = WeatherSnapshot(
                        temperatureCelsius: Double.random(in: 10...28),
                        feelsLikeCelsius: Double.random(in: 8...30),
                        humidityPercent: Double.random(in: 0.3...0.8),
                        windSpeedMPS: Double.random(in: 0.5...8.0),
                        conditionName: ["Clear", "Partly Cloudy", "Cloudy", "Rain"].randomElement()!,
                        conditionSymbol: ["sun.max.fill", "cloud.sun.fill", "cloud.fill", "cloud.rain.fill"].randomElement()!
                    )
                }
            }
            #endif
        }

        // Start audio cues
        audioCueService.startListening(
            splitPublisher: splitTracker.splitPublisher,
            unitSystem: unitSystem,
            splitDistance: splitDistanceSetting
        )

        // Announce countdown completion
        audioCueService.speakCountdownComplete()
    }

    func pauseRun() {
        guard runState == .active else { return }
        runState = .paused
        stopTimer()
        locationProvider.pauseTracking()
        motionProvider.stopCadenceUpdates()
        audioCueService.stopListening()
    }

    func resumeRun() {
        guard runState == .paused else { return }
        runState = .active
        isResumePoint = true
        startTimer()

        locationProvider.resumeTracking()
        motionProvider.startCadenceUpdates(from: Date())

        // Resume audio cues
        audioCueService.startListening(
            splitPublisher: splitTracker.splitPublisher,
            unitSystem: unitSystem,
            splitDistance: splitDistanceSetting
        )
    }

    func stopRun() {
        guard runState == .active || runState == .paused else { return }

        // Re-enable screen auto-lock
        UIApplication.shared.isIdleTimerDisabled = false

        // Stop services
        stopTimer()
        locationProvider.stopTracking()
        motionProvider.stopCadenceUpdates()
        audioCueService.stopListening()

        // Announce run complete after stopping (speak manages its own audio session)
        audioCueService.speakRunComplete()
        cancellables.removeAll()

        // Build the completed Run model
        let run = Run(
            startDate: startDate ?? Date(),
            endDate: Date(),
            distanceMeters: totalDistanceMeters,
            durationSeconds: elapsedSeconds,
            elevationGainMeters: elevationGainMeters,
            elevationLossMeters: elevationLossMeters,
            averagePaceSecondsPerKm: totalDistanceMeters > 0
                ? (elapsedSeconds / totalDistanceMeters) * 1000.0
                : nil,
            averageCadence: currentCadence,
            totalSteps: totalSteps
        )

        // Set cool-down aggregate fields
        run.hasCoolDown = hadCoolDownDuringRun
        run.coolDownDistanceMeters = coolDownDistanceAccumMeters
        run.coolDownDurationSeconds = coolDownDurationAccumSeconds
        run.timeToFirstWalkSeconds = timeToFirstWalkSeconds

        // Add final partial split
        if var finalSplit = splitTracker.finalSplit(
            totalDistanceMeters: totalDistanceMeters,
            totalDurationSeconds: elapsedSeconds,
            elevationGainMeters: elevationGainMeters,
            elevationLossMeters: elevationLossMeters
        ) {
            finalSplit.isCoolDown = isCoolDownActive
            collectedSplits.append(finalSplit)
        }

        // Convert split snapshots to Split models
        for snapshot in collectedSplits {
            let split = Split(
                splitIndex: snapshot.splitIndex,
                distanceMeters: snapshot.distanceMeters,
                durationSeconds: snapshot.durationSeconds,
                elevationGainMeters: snapshot.elevationGainMeters,
                elevationLossMeters: snapshot.elevationLossMeters,
                averageCadence: snapshot.averageCadence,
                startDate: snapshot.startDate,
                endDate: snapshot.endDate,
                isPartial: snapshot.isPartial,
                isCoolDown: snapshot.isCoolDown
            )
            split.run = run
            run.splits.append(split)
        }

        // Convert route points
        for point in routePoints {
            let routePoint = RoutePoint(
                timestamp: point.timestamp,
                latitude: point.location.coordinate.latitude,
                longitude: point.location.coordinate.longitude,
                altitude: point.location.altitude,
                smoothedAltitude: point.smoothedAltitude ?? point.location.altitude,
                horizontalAccuracy: point.location.horizontalAccuracy,
                speed: point.location.speed,
                distanceFromStart: point.distanceFromStart
            )
            routePoint.run = run
            run.routePoints.append(routePoint)
        }

        // Write weather data
        if let weather = weatherSnapshot {
            run.temperatureCelsius = weather.temperatureCelsius
            run.feelsLikeCelsius = weather.feelsLikeCelsius
            run.humidityPercent = weather.humidityPercent
            run.windSpeedMPS = weather.windSpeedMPS
            run.weatherCondition = weather.conditionName
            run.weatherConditionSymbol = weather.conditionSymbol
        }

        // Set total laps
        run.totalLaps = max(1, currentLap + (nextCheckpointIndex > 0 ? 1 : 0))

        // Append checkpoint results
        for result in pendingCheckpointResults {
            result.run = run
            run.checkpointResults.append(result)
        }

        // Auto-assign pre-selected route
        if let selectedRoute = selectedNamedRoute {
            run.namedRoute = selectedRoute
        }

        completedRun = run
        runState = .idle
    }

    // MARK: - Cool Down

    func toggleCoolDown() {
        isCoolDownActive.toggle()
        audioCueService.isCoolDownActive = isCoolDownActive
        if isCoolDownActive && (runState == .active || runState == .paused) {
            hadCoolDownDuringRun = true
            if timeToFirstWalkSeconds == nil {
                timeToFirstWalkSeconds = elapsedSeconds
            }
        }
        if runState == .active {
            let cueText = isCoolDownActive ? "Walking started." : "Running resumed."
            audioCueService.speakOneShot(cueText)
        }
    }

    var runningOnlyDistanceMeters: Double {
        totalDistanceMeters - coolDownDistanceAccumMeters
    }

    var runningOnlyDurationSeconds: Double {
        elapsedSeconds - coolDownDurationAccumSeconds
    }

    // MARK: - Checkpoints

    func dropCheckpoint() {
        guard runState == .active || runState == .paused else { return }
        guard let location = currentUserLocation else { return }

        if let route = selectedNamedRoute {
            guard route.checkpoints.count < 20 else { return }

            let checkpoint = RouteCheckpoint(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                label: "Checkpoint \(route.checkpoints.count + 1)",
                order: route.checkpoints.count,
                namedRoute: route
            )
            route.checkpoints.append(checkpoint)

            let result = RunCheckpointResult(
                elapsedSeconds: elapsedSeconds,
                cumulativeDistanceMeters: totalDistanceMeters,
                lapNumber: currentLap,
                checkpoint: checkpoint
            )
            pendingCheckpointResults.append(result)

            // Add to routeCheckpoints if at or past the current detection index
            if nextCheckpointIndex >= routeCheckpoints.count {
                routeCheckpoints.append(checkpoint)
            }

            latestCheckpointWasManualDrop = true
            latestCheckpointResult = (result: result, delta: nil)
            checkpointResultCounter += 1
        } else {
            // Free run — store checkpoint locally
            guard pendingFreeRunCheckpoints.count < 20 else { return }

            let checkpoint = RouteCheckpoint(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                label: "Checkpoint \(pendingFreeRunCheckpoints.count + 1)",
                order: pendingFreeRunCheckpoints.count
            )
            pendingFreeRunCheckpoints.append(checkpoint)

            let result = RunCheckpointResult(
                elapsedSeconds: elapsedSeconds,
                cumulativeDistanceMeters: totalDistanceMeters,
                lapNumber: currentLap,
                checkpoint: checkpoint
            )
            pendingCheckpointResults.append(result)

            // Add to routeCheckpoints for map display
            routeCheckpoints.append(checkpoint)

            latestCheckpointWasManualDrop = true
            latestCheckpointResult = (result: result, delta: nil)
            checkpointResultCounter += 1
        }
    }

    /// Proximity radius within which we start tracking closest approach (meters).
    /// Uses the shared trail characteristic distance (trail width + GPS jitter).
    private let checkpointProximityRadius: Double = BearingUtils.trailProximityRadius
    /// Minimum distance the runner must move away from closest approach to confirm they've passed (meters).
    private let checkpointDepartureThreshold: Double = 3.0
    /// Maximum bearing difference (degrees) to accept as the correct direction of approach.
    private let bearingTolerance: Double = 60.0
    /// Distance threshold for auto-detecting loop routes (meters).
    private let loopDetectionThreshold: Double = BearingUtils.trailProximityRadius

    private func checkCheckpointProximity(_ location: CLLocation) {
        guard nextCheckpointIndex < routeCheckpoints.count else {
            // If loop route and all checkpoints passed, wrap to next lap
            if isLoopRoute {
                completeLap()
            }
            return
        }
        let checkpoint = routeCheckpoints[nextCheckpointIndex]

        // Skip if a result already exists for this checkpoint on the current lap
        if pendingCheckpointResults.contains(where: {
            $0.checkpoint?.id == checkpoint.id && $0.lapNumber == currentLap
        }) {
            advanceToNextCheckpoint()
            return
        }

        let checkpointLocation = CLLocation(latitude: checkpoint.latitude, longitude: checkpoint.longitude)
        let distance = location.distance(from: checkpointLocation)

        guard distance <= checkpointProximityRadius else {
            // Not close enough yet — reset tracking if we had a stale approach
            if closestDistanceToNextCheckpoint < .greatestFiniteMagnitude && distance > checkpointProximityRadius * 2.0 {
                closestDistanceToNextCheckpoint = .greatestFiniteMagnitude
                closestApproachLocation = nil
            }
            return
        }

        // We're within the proximity zone. Track closest approach.
        if distance < closestDistanceToNextCheckpoint {
            closestDistanceToNextCheckpoint = distance
            closestApproachLocation = location
        }

        // Check if runner is now moving away from the checkpoint (passed it).
        let departedDistance = distance - closestDistanceToNextCheckpoint
        guard departedDistance >= checkpointDepartureThreshold else { return }

        // Direction gate: reject crossings from the wrong direction
        if let expectedBearing = checkpoint.expectedApproachBearing,
           location.course >= 0 {
            if !BearingUtils.isBearingWithinTolerance(
                actual: location.course,
                expected: expectedBearing,
                tolerance: bearingTolerance
            ) {
                // Wrong direction — reset and skip
                closestDistanceToNextCheckpoint = .greatestFiniteMagnitude
                closestApproachLocation = nil
                return
            }
        }

        // Runner has passed the checkpoint — record the result at the closest approach point
        recordCheckpointResult(checkpoint: checkpoint)
    }

    private func recordCheckpointResult(checkpoint: RouteCheckpoint) {
        let result = RunCheckpointResult(
            elapsedSeconds: elapsedSeconds,
            cumulativeDistanceMeters: totalDistanceMeters,
            lapNumber: currentLap,
            checkpoint: checkpoint
        )
        pendingCheckpointResults.append(result)

        let key = LapCheckpointKey(checkpointID: checkpoint.id, lap: currentLap)

        let previousDelta: Double?
        if let benchmarkTime = benchmarkCheckpointResults[key] {
            previousDelta = elapsedSeconds - benchmarkTime
        } else {
            previousDelta = nil
        }

        let averageDelta: Double?
        if let avgTime = averageCheckpointResults[key] {
            averageDelta = elapsedSeconds - avgTime
        } else {
            averageDelta = nil
        }

        audioCueService.announceCheckpoint(
            label: checkpoint.label,
            elapsedSeconds: elapsedSeconds,
            distanceMeters: totalDistanceMeters,
            unitSystem: unitSystem,
            previousDelta: previousDelta,
            averageDelta: averageDelta,
            lapNumber: isLoopRoute ? currentLap + 1 : nil
        )

        latestCheckpointWasManualDrop = false
        latestCheckpointResult = (result: result, delta: previousDelta)
        checkpointResultCounter += 1
        advanceToNextCheckpoint()
    }

    private func advanceToNextCheckpoint() {
        nextCheckpointIndex += 1
        closestDistanceToNextCheckpoint = .greatestFiniteMagnitude
        closestApproachLocation = nil
    }

    private func completeLap() {
        let lapTime = elapsedSeconds - lapStartElapsedSeconds
        lapTimes.append(lapTime)

        audioCueService.announceLapCompletion(
            lapNumber: currentLap + 1,
            lapTime: lapTime,
            totalElapsed: elapsedSeconds,
            unitSystem: unitSystem
        )

        currentLap += 1
        nextCheckpointIndex = 0
        lapStartElapsedSeconds = elapsedSeconds
        lapStartDistanceMeters = totalDistanceMeters
        closestDistanceToNextCheckpoint = .greatestFiniteMagnitude
        closestApproachLocation = nil
    }

    private func detectLoopRoute(route: NamedRoute) -> Bool {
        let sorted = route.checkpoints.sorted { $0.order < $1.order }
        if sorted.count >= 2,
           let first = sorted.first, let last = sorted.last {
            let firstLoc = CLLocation(latitude: first.latitude, longitude: first.longitude)
            let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
            if firstLoc.distance(from: lastLoc) < loopDetectionThreshold {
                return true
            }
        }

        // Fallback: check route polyline start/end
        if let start = namedRouteCoordinates.first, let end = namedRouteCoordinates.last {
            let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
            let endLoc = CLLocation(latitude: end.latitude, longitude: end.longitude)
            if startLoc.distance(from: endLoc) < loopDetectionThreshold {
                return true
            }
        }

        return false
    }

    // MARK: - Named Route

    var hasActiveNamedRoute: Bool {
        activeNamedRoute != nil && !namedRouteCoordinates.isEmpty
    }

    func setNamedRoute(_ route: NamedRoute?) {
        activeNamedRoute = route
        namedRouteCoordinates = []
        routeComparison.reset()
        guard let route else { return }

        // Load benchmark for route comparison
        routeComparison.loadBenchmark(for: route)

        // Load coach data
        routeComparison.loadCoachData(for: route)

        // Use benchmark route coordinates if available, otherwise best run
        if !routeComparison.benchmarkRouteCoordinates.isEmpty {
            namedRouteCoordinates = routeComparison.benchmarkRouteCoordinates
        } else {
            let bestRun = route.runs
                .filter { !$0.routePoints.isEmpty }
                .sorted { ($0.averagePaceSecondsPerKm ?? .infinity) < ($1.averagePaceSecondsPerKm ?? .infinity) }
                .first
            guard let bestRun else { return }
            var points = bestRun.routePoints.sorted { $0.distanceFromStart < $1.distanceFromStart }
            if let maxDist = route.singleLapMaxDistance {
                points = points.filter { $0.distanceFromStart <= maxDist }
            }
            namedRouteCoordinates = points
                .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }

        // Also filter benchmark coordinates if single-lap trimming is set
        if let maxDist = route.singleLapMaxDistance,
           !namedRouteCoordinates.isEmpty {
            // benchmarkRouteCoordinates don't have distanceFromStart, so re-derive from the
            // benchmark run's route points if available
            if let benchmarkRunID = route.benchmarkRunID,
               let benchmarkRun = route.runs.first(where: { $0.id == benchmarkRunID && !$0.routePoints.isEmpty }) {
                let trimmedPoints = benchmarkRun.routePoints
                    .sorted { $0.distanceFromStart < $1.distanceFromStart }
                    .filter { $0.distanceFromStart <= maxDist }
                namedRouteCoordinates = trimmedPoints
                    .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            }
        }
    }

    // MARK: - Computed Properties

    var averagePaceSecondsPerMeter: Double {
        guard totalDistanceMeters > 0 else { return 0 }
        return elapsedSeconds / totalDistanceMeters
    }

    var isCurrentPaceAvailable: Bool {
        currentPaceSecondsPerMeter > 0
    }

    /// Pace of the last completed (non-partial) split in seconds per meter
    var lastCompletedSplitPace: Double {
        guard let lastSplit = collectedSplits.last(where: { !$0.isPartial }),
              lastSplit.distanceMeters > 0 else { return 0 }
        return lastSplit.durationSeconds / lastSplit.distanceMeters
    }

    // MARK: - Timer

    private func startTimer() {
        // .common run loop mode is required for timer to fire during background execution
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.runState == .active else { return }
                self.elapsedSeconds += 1
                if self.isCoolDownActive {
                    self.coolDownDurationAccumSeconds += 1
                }
                self.audioCueService.updateRunStats(
                    elapsedSeconds: self.elapsedSeconds,
                    distanceMeters: self.totalDistanceMeters,
                    avgPaceSecondsPerMeter: self.averagePaceSecondsPerMeter,
                    lastSplitPaceSecondsPerMeter: self.lastCompletedSplitPace
                )
                self.checkTimeMarker()
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // MARK: - Location Subscription

    private func subscribeToLocation() {
        locationProvider.locationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
            .store(in: &cancellables)
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        // Always update accuracy and location for GPS indicator / idle map
        currentHorizontalAccuracy = location.horizontalAccuracy
        currentUserLocation = location

        guard runState == .active else { return }
        guard location.horizontalAccuracy <= maximumAccuracy,
              location.horizontalAccuracy >= 0 else { return }

        if let previous = previousLocation {
            let distance = location.distance(from: previous)

            // Skip if below minimum movement threshold
            guard distance >= minimumMovementThreshold else { return }

            totalDistanceMeters += distance
            if isCoolDownActive {
                coolDownDistanceAccumMeters += distance
            }
        }

        // Feed altitude to elevation filter
        let smoothedAltitude = elevationFilter.addAltitude(location.altitude)
        elevationGainMeters = elevationFilter.elevationGain
        elevationLossMeters = elevationFilter.elevationLoss

        // Store route point
        routePoints.append((
            location: location,
            distanceFromStart: totalDistanceMeters,
            smoothedAltitude: smoothedAltitude,
            timestamp: location.timestamp
        ))

        // Update split tracker
        splitTracker.updateDistance(
            totalDistanceMeters: totalDistanceMeters,
            totalDurationSeconds: elapsedSeconds,
            elevationGainMeters: elevationGainMeters,
            elevationLossMeters: elevationLossMeters,
            currentCadence: currentCadence,
            timeDelta: previousLocation != nil ? location.timestamp.timeIntervalSince(previousLocation!.timestamp) : 0
        )

        // Check checkpoint proximity
        checkCheckpointProximity(location)

        // Update polyline coordinates (throttled to every 3 seconds)
        updatePolylineIfNeeded(location)

        // Recalculate current pace (throttled to every 5 seconds)
        recalculatePaceIfNeeded()

        // Mark resume point used
        if isResumePoint {
            isResumePoint = false
        }

        previousLocation = location
    }

    // MARK: - Polyline Updates

    private func updatePolylineIfNeeded(_ location: CLLocation) {
        let now = Date()
        if let lastUpdate = lastPolylineUpdateTime,
           now.timeIntervalSince(lastUpdate) < polylineUpdateInterval {
            return
        }
        lastPolylineUpdateTime = now
        displayedRouteCoordinates.append(location.coordinate)
        rebuildElevationSegments()
    }

    private func rebuildElevationSegments() {
        let points: [(coordinate: CLLocationCoordinate2D, smoothedAltitude: Double)] = routePoints.map {
            (coordinate: $0.location.coordinate, smoothedAltitude: $0.smoothedAltitude ?? $0.location.altitude)
        }
        elevationRouteSegments = ElevationColor.buildSegments(from: points)

        let altitudes = routePoints.compactMap { $0.smoothedAltitude ?? $0.location.altitude as Double? }
        if let minAlt = altitudes.min(), let maxAlt = altitudes.max() {
            elevationRange = (min: minAlt, max: maxAlt)
        }

        // Rebuild pace segments alongside elevation
        let pacePoints: [(coordinate: CLLocationCoordinate2D, location: CLLocation)] = routePoints.map {
            (coordinate: $0.location.coordinate, location: $0.location)
        }
        let result = PaceColor.buildSegments(from: pacePoints)
        paceRouteSegments = result.segments
        paceRange = result.paceRange
    }

    // MARK: - Time Markers

    private func checkTimeMarker() {
        guard timeMarkersEnabled else { return }
        guard elapsedSeconds >= nextTimeMarkerSeconds else { return }
        guard let lastPoint = routePoints.last else { return }

        let minutes = Int(nextTimeMarkerSeconds) / 60
        let formattedTime: String
        if minutes >= 60 {
            formattedTime = String(format: "%d:%02d:00", minutes / 60, minutes % 60)
        } else {
            formattedTime = String(format: "%d:00", minutes)
        }

        timeMarkers.append(TimeMarker(
            coordinate: lastPoint.location.coordinate,
            elapsedSeconds: nextTimeMarkerSeconds,
            formattedTime: formattedTime
        ))

        nextTimeMarkerSeconds += Double(timeMarkerIntervalMinutes * 60)
    }

    // MARK: - Pace Calculation

    private func recalculatePaceIfNeeded() {
        let now = Date()
        if let lastRecalc = lastPaceRecalcTime,
           now.timeIntervalSince(lastRecalc) < paceRecalcInterval {
            return
        }
        lastPaceRecalcTime = now
        recalculateCurrentPace()
    }

    /// Force recalculate current pace (used by tests and internal logic)
    func recalculateCurrentPace() {
        guard routePoints.count >= 2 else {
            currentPaceSecondsPerMeter = 0
            return
        }

        let now = routePoints.last!.timestamp
        let windowStart = now.addingTimeInterval(-paceWindowDuration)

        // Find points within the rolling window
        let windowPoints = routePoints.filter { $0.timestamp >= windowStart }
        guard windowPoints.count >= 2 else {
            currentPaceSecondsPerMeter = 0
            return
        }

        // Check if all speeds are below threshold (stopped/very slow)
        let allSlow = windowPoints.allSatisfy { $0.location.speed < slowSpeedThreshold }
        if allSlow {
            currentPaceSecondsPerMeter = 0
            return
        }

        let windowDistance = windowPoints.last!.distanceFromStart - windowPoints.first!.distanceFromStart
        let windowTime = windowPoints.last!.timestamp.timeIntervalSince(windowPoints.first!.timestamp)

        guard windowDistance > 0, windowTime > 0 else {
            currentPaceSecondsPerMeter = 0
            return
        }

        currentPaceSecondsPerMeter = windowTime / windowDistance
    }

    // MARK: - Motion Subscription

    private func subscribeToMotion() {
        motionProvider.cadencePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cadence in
                self?.currentCadence = cadence
            }
            .store(in: &cancellables)

        motionProvider.stepsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] steps in
                self?.totalSteps = steps
            }
            .store(in: &cancellables)
    }

    // MARK: - Split Subscription

    private func subscribeToSplits() {
        splitTracker.splitPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] split in
                guard let self else { return }
                var taggedSplit = split
                taggedSplit.isCoolDown = self.isCoolDownActive
                self.latestSplit = taggedSplit
                self.collectedSplits.append(taggedSplit)

                // Update route comparison with cumulative time
                if !split.isPartial {
                    let cumulativeTime = self.collectedSplits
                        .filter { !$0.isPartial }
                        .reduce(0.0) { $0 + $1.durationSeconds }
                    self.routeComparison.updateComparison(
                        currentSplitIndex: split.splitIndex,
                        currentCumulativeTime: cumulativeTime
                    )

                    // Update audio cue service with coach data
                    self.audioCueService.isCoachModeEnabled = self.isCoachModeEnabled
                    if self.isCoachModeEnabled {
                        // Derive per-split times from cumulative times
                        let cumulatives = self.routeComparison.lastRunCumulativeSplitTimes
                        var perSplitTimes: [TimeInterval] = []
                        for i in 0..<cumulatives.count {
                            if i == 0 {
                                perSplitTimes.append(cumulatives[i])
                            } else {
                                perSplitTimes.append(cumulatives[i] - cumulatives[i - 1])
                            }
                        }

                        let splitPace = split.distanceMeters > 0 ? split.durationSeconds / split.distanceMeters : 0

                        self.audioCueService.coachData = AudioCueService.CoachData(
                            lastRunCumulativeSplitTimes: cumulatives,
                            lastRunPerSplitTimes: perSplitTimes,
                            currentCumulativeTime: cumulativeTime,
                            currentSplitDuration: split.durationSeconds,
                            currentSplitPaceSecondsPerMeter: splitPace,
                            currentAvgPaceSecondsPerMeter: self.currentPaceSecondsPerMeter
                        )
                    } else {
                        self.audioCueService.coachData = nil
                    }
                }
            }
            .store(in: &cancellables)
    }
}
