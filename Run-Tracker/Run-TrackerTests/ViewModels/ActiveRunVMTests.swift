//
//  ActiveRunVMTests.swift
//  Run-TrackerTests
//

import XCTest
import CoreLocation
import Combine
import SwiftData
@testable import Run_Tracker

// MARK: - Mock Location Provider

final class MockLocationProvider: LocationProviding {
    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    private let authSubject = CurrentValueSubject<CLAuthorizationStatus, Never>(.authorizedWhenInUse)

    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus { authSubject.value }

    var locationPublisher: AnyPublisher<CLLocation, Never> {
        locationSubject.eraseToAnyPublisher()
    }
    var authorizationPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        authSubject.eraseToAnyPublisher()
    }

    var startTrackingCalled = false
    var stopTrackingCalled = false
    var pauseTrackingCalled = false
    var resumeTrackingCalled = false

    func startTracking() { startTrackingCalled = true }
    func stopTracking() { stopTrackingCalled = true }
    func pauseTracking() { pauseTrackingCalled = true }
    func resumeTracking() { resumeTrackingCalled = true }

    func simulateLocation(_ location: CLLocation) {
        currentLocation = location
        locationSubject.send(location)
    }
}

// MARK: - Mock Motion Provider

final class MockMotionProvider: MotionProviding {
    private let cadenceSubject = CurrentValueSubject<Double?, Never>(nil)
    private let stepsSubject = CurrentValueSubject<Int, Never>(0)

    var currentCadence: Double? { cadenceSubject.value }
    var totalSteps: Int { stepsSubject.value }

    var cadencePublisher: AnyPublisher<Double?, Never> {
        cadenceSubject.eraseToAnyPublisher()
    }
    var stepsPublisher: AnyPublisher<Int, Never> {
        stepsSubject.eraseToAnyPublisher()
    }

    var startCalled = false
    var stopCalled = false

    func startCadenceUpdates(from startDate: Date) { startCalled = true }
    func stopCadenceUpdates() { stopCalled = true }

    func simulateCadence(_ cadence: Double?) {
        cadenceSubject.send(cadence)
    }

    func simulateSteps(_ steps: Int) {
        stepsSubject.send(steps)
    }
}

// MARK: - Helper

private func makeLocation(
    lat: Double,
    lon: Double,
    altitude: Double = 100,
    accuracy: Double = 5,
    speed: Double = 3.0,
    course: Double = 0,
    timestamp: Date = Date()
) -> CLLocation {
    CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
        altitude: altitude,
        horizontalAccuracy: accuracy,
        verticalAccuracy: 5,
        course: course,
        speed: speed,
        timestamp: timestamp
    )
}

// MARK: - Tests

final class ActiveRunVMTests: XCTestCase {
    private var mockLocation: MockLocationProvider!
    private var mockMotion: MockMotionProvider!
    private var vm: ActiveRunVM!

    override func setUp() {
        super.setUp()
        mockLocation = MockLocationProvider()
        mockMotion = MockMotionProvider()
        vm = ActiveRunVM(
            locationProvider: mockLocation,
            motionProvider: mockMotion,
            unitSystem: .imperial
        )
    }

    override func tearDown() {
        vm = nil
        mockLocation = nil
        mockMotion = nil
        super.tearDown()
    }

    // MARK: - State Transitions

    func testInitialStateIsIdle() {
        XCTAssertEqual(vm.runState, .idle)
    }

    func testStartRunTransitionsToCountdown() {
        vm.startRun()
        XCTAssertEqual(vm.runState, .countdown)
        XCTAssertTrue(mockLocation.startTrackingCalled)
    }

    func testStartRunNowTransitionsToActive() {
        vm.startRunNow()
        XCTAssertEqual(vm.runState, .active)
        XCTAssertTrue(mockLocation.startTrackingCalled)
        XCTAssertTrue(mockMotion.startCalled)
    }

    func testPauseRunTransitionsToPaused() {
        vm.startRunNow()
        vm.pauseRun()
        XCTAssertEqual(vm.runState, .paused)
        XCTAssertTrue(mockLocation.pauseTrackingCalled)
        XCTAssertTrue(mockMotion.stopCalled)
    }

    func testResumeRunTransitionsToActive() {
        vm.startRunNow()
        vm.pauseRun()
        vm.resumeRun()
        XCTAssertEqual(vm.runState, .active)
        XCTAssertTrue(mockLocation.resumeTrackingCalled)
    }

    func testStopRunTransitionsToIdle() {
        vm.startRunNow()
        vm.stopRun()
        XCTAssertEqual(vm.runState, .idle)
        XCTAssertTrue(mockLocation.stopTrackingCalled)
    }

    func testStopFromPausedTransitionsToIdle() {
        vm.startRunNow()
        vm.pauseRun()
        vm.stopRun()
        XCTAssertEqual(vm.runState, .idle)
    }

    func testCannotPauseFromIdle() {
        vm.pauseRun()
        XCTAssertEqual(vm.runState, .idle)
    }

    func testCannotResumeFromIdle() {
        vm.resumeRun()
        XCTAssertEqual(vm.runState, .idle)
    }

    func testCannotStartFromActive() {
        vm.startRunNow()
        let elapsed = vm.elapsedSeconds
        vm.startRunNow() // should be ignored
        XCTAssertEqual(vm.runState, .active)
        XCTAssertEqual(vm.elapsedSeconds, elapsed)
    }

    // MARK: - Timer

    func testTimerIncrementsWhenActive() {
        vm.startRunNow()
        // Timer publishes on main run loop every 1s. Simulate by waiting.
        let expectation = expectation(description: "Timer increments")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 4)
        XCTAssertGreaterThanOrEqual(vm.elapsedSeconds, 2)
    }

    func testTimerStopsWhenPaused() {
        vm.startRunNow()
        let exp1 = expectation(description: "Wait for timer")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 3)

        vm.pauseRun()
        let elapsedAtPause = vm.elapsedSeconds

        let exp2 = expectation(description: "Wait after pause")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 3)

        // Elapsed should not have increased (or only by the margin of the tick that was in-flight)
        XCTAssertEqual(vm.elapsedSeconds, elapsedAtPause, accuracy: 1.0)
    }

    // MARK: - Distance Accumulation

    func testDistanceAccumulation() {
        vm.startRunNow()

        let baseTime = Date()
        // Two points ~111m apart (roughly 0.001 degrees latitude)
        let loc1 = makeLocation(lat: 37.0, lon: -122.0, timestamp: baseTime)
        let loc2 = makeLocation(lat: 37.001, lon: -122.0, timestamp: baseTime.addingTimeInterval(30))

        mockLocation.simulateLocation(loc1)

        let exp = expectation(description: "Process locations")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.mockLocation.simulateLocation(loc2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 2)

        // ~111 meters between points
        XCTAssertGreaterThan(vm.totalDistanceMeters, 100)
        XCTAssertLessThan(vm.totalDistanceMeters, 120)
    }

    func testDistanceNotAccumulatedWhenPaused() {
        vm.startRunNow()

        let baseTime = Date()
        let loc1 = makeLocation(lat: 37.0, lon: -122.0, timestamp: baseTime)
        mockLocation.simulateLocation(loc1)

        let exp1 = expectation(description: "First location")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 1)

        vm.pauseRun()

        let loc2 = makeLocation(lat: 37.001, lon: -122.0, timestamp: baseTime.addingTimeInterval(30))
        mockLocation.simulateLocation(loc2)

        let exp2 = expectation(description: "Second location")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 1)

        XCTAssertEqual(vm.totalDistanceMeters, 0, accuracy: 0.1)
    }

    func testRejectsLowAccuracyFixes() {
        vm.startRunNow()

        let baseTime = Date()
        let loc1 = makeLocation(lat: 37.0, lon: -122.0, accuracy: 5, timestamp: baseTime)
        let loc2 = makeLocation(lat: 37.001, lon: -122.0, accuracy: 100, timestamp: baseTime.addingTimeInterval(30))

        mockLocation.simulateLocation(loc1)
        let exp = expectation(description: "Process locations")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.mockLocation.simulateLocation(loc2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 2)

        // Should not have accumulated distance from low accuracy fix
        XCTAssertEqual(vm.totalDistanceMeters, 0, accuracy: 0.1)
    }

    // MARK: - Elevation Tracking

    func testElevationTracking() {
        vm.startRunNow()

        let baseTime = Date()
        // Send enough points to fill the elevation filter buffer (5 points)
        // and then see gain
        var lat = 37.0
        for i in 0..<7 {
            lat += 0.0001 // small movement to pass threshold
            let altitude = 100.0 + Double(i) * 2.0 // 2m gain per point
            let loc = makeLocation(
                lat: lat,
                lon: -122.0,
                altitude: altitude,
                timestamp: baseTime.addingTimeInterval(Double(i) * 5)
            )
            mockLocation.simulateLocation(loc)
        }

        let exp = expectation(description: "Process elevations")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)

        // After 7 points with 2m increments, the smoothed values should show gain
        XCTAssertGreaterThan(vm.elevationGainMeters, 0)
    }

    // MARK: - Pace Calculation

    func testAveragePaceWithDistance() {
        vm.startRunNow()

        let baseTime = Date()
        let loc1 = makeLocation(lat: 37.0, lon: -122.0, speed: 3.0, timestamp: baseTime)
        let loc2 = makeLocation(lat: 37.001, lon: -122.0, speed: 3.0, timestamp: baseTime.addingTimeInterval(30))

        mockLocation.simulateLocation(loc1)

        // Wait for timer to tick at least once so elapsedSeconds > 0
        let exp = expectation(description: "Pace calc")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.mockLocation.simulateLocation(loc2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 3)

        // Average pace should be > 0 since we have both distance and elapsed time
        XCTAssertGreaterThan(vm.totalDistanceMeters, 0)
        XCTAssertGreaterThan(vm.elapsedSeconds, 0)
        XCTAssertGreaterThan(vm.averagePaceSecondsPerMeter, 0)
    }

    func testAveragePaceZeroWithNoDistance() {
        vm.startRunNow()
        XCTAssertEqual(vm.averagePaceSecondsPerMeter, 0)
    }

    func testCurrentPaceZeroWhenSlow() {
        vm.startRunNow()

        let baseTime = Date()
        // Send points with speed below threshold
        let loc1 = makeLocation(lat: 37.0, lon: -122.0, speed: 0.1, timestamp: baseTime)
        let loc2 = makeLocation(lat: 37.0001, lon: -122.0, speed: 0.1, timestamp: baseTime.addingTimeInterval(10))

        mockLocation.simulateLocation(loc1)
        let exp = expectation(description: "Slow pace")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.mockLocation.simulateLocation(loc2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Force recalc
                self.vm.recalculateCurrentPace()
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 2)

        XCTAssertEqual(vm.currentPaceSecondsPerMeter, 0)
    }

    // MARK: - Cadence

    func testCadenceUpdates() {
        vm.startRunNow()

        mockMotion.simulateCadence(162.0)
        mockMotion.simulateSteps(500)

        let exp = expectation(description: "Cadence update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)

        XCTAssertEqual(vm.currentCadence, 162.0)
        XCTAssertEqual(vm.totalSteps, 500)
    }

    // MARK: - Polyline Updates

    func testPolylineThrottling() {
        vm.startRunNow()

        let baseTime = Date()
        // Send multiple locations rapidly
        for i in 0..<5 {
            let loc = makeLocation(
                lat: 37.0 + Double(i) * 0.0001,
                lon: -122.0,
                timestamp: baseTime.addingTimeInterval(Double(i) * 0.5) // 0.5s apart
            )
            mockLocation.simulateLocation(loc)
        }

        let exp = expectation(description: "Polyline update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)

        // Should not have all 5 points due to 3s throttle — should have at most 2
        // (first point gets added, then throttle kicks in)
        XCTAssertLessThanOrEqual(vm.displayedRouteCoordinates.count, 2)
    }

    // MARK: - Completed Run Persistence

    func testStopRunBuildsCompletedRun() {
        vm.startRunNow()

        let baseTime = Date()
        let loc1 = makeLocation(lat: 37.0, lon: -122.0, altitude: 100, timestamp: baseTime)
        let loc2 = makeLocation(lat: 37.001, lon: -122.0, altitude: 105, timestamp: baseTime.addingTimeInterval(30))

        mockLocation.simulateLocation(loc1)

        let exp = expectation(description: "Process locations")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.mockLocation.simulateLocation(loc2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 2)

        // Wait for timer to tick
        let exp2 = expectation(description: "Timer tick")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 3)

        vm.stopRun()

        // completedRun should be set
        XCTAssertNotNil(vm.completedRun)

        let run = vm.completedRun!
        XCTAssertNotNil(run.endDate)
        XCTAssertGreaterThan(run.distanceMeters, 100)
        XCTAssertGreaterThan(run.durationSeconds, 0)
        XCTAssertGreaterThan(run.routePoints.count, 0)
    }

    func testCompletedRunAppearsInHistory() {
        vm.startRunNow()

        let baseTime = Date()
        let loc1 = makeLocation(lat: 37.0, lon: -122.0, timestamp: baseTime)
        let loc2 = makeLocation(lat: 37.001, lon: -122.0, timestamp: baseTime.addingTimeInterval(30))

        mockLocation.simulateLocation(loc1)
        let exp = expectation(description: "Process")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.mockLocation.simulateLocation(loc2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 2)

        vm.stopRun()

        guard let completedRun = vm.completedRun else {
            XCTFail("completedRun should not be nil")
            return
        }

        // Simulate what the view does: insert into an in-memory SwiftData container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Run.self, Split.self, RoutePoint.self, NamedRoute.self, RouteCheckpoint.self, RunCheckpointResult.self, configurations: config)
        let context = ModelContext(container)

        let service = RunPersistenceService(modelContext: context)
        service.saveRun(completedRun)

        // Fetch and verify it appears
        let fetched = service.fetchAllRunsSorted()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, completedRun.id)
        XCTAssertNotNil(fetched.first?.endDate)
    }

    // MARK: - Reset on Start

    func testStartResetsState() {
        vm.startRunNow()
        let baseTime = Date()
        let loc1 = makeLocation(lat: 37.0, lon: -122.0, timestamp: baseTime)
        let loc2 = makeLocation(lat: 37.001, lon: -122.0, timestamp: baseTime.addingTimeInterval(30))
        mockLocation.simulateLocation(loc1)
        mockLocation.simulateLocation(loc2)

        let exp1 = expectation(description: "First run")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 1)

        vm.stopRun()

        // Start a new run
        vm.startRunNow()
        XCTAssertEqual(vm.totalDistanceMeters, 0)
        XCTAssertEqual(vm.elapsedSeconds, 0)
        XCTAssertEqual(vm.elevationGainMeters, 0)
        XCTAssertEqual(vm.elevationLossMeters, 0)
        XCTAssertTrue(vm.displayedRouteCoordinates.isEmpty)
        XCTAssertNil(vm.latestSplit)
    }

    // MARK: - Route Selection / Auto-Assign

    func testSelectedNamedRouteIsStoredOnCompletedRun() {
        let route = NamedRoute(name: "Test Route")
        vm.selectedNamedRoute = route
        vm.startRunNow()

        // Simulate some location to produce a non-trivial run
        let loc = makeLocation(lat: 40.0, lon: -74.0, timestamp: Date())
        let exp = expectation(description: "location")
        mockLocation.simulateLocation(loc)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        vm.stopRun()

        XCTAssertNotNil(vm.completedRun)
        XCTAssertEqual(vm.completedRun?.namedRoute?.name, "Test Route")
    }

    func testNoRouteSelectedMeansNoAutoAssign() {
        vm.selectedNamedRoute = nil
        vm.startRunNow()

        let loc = makeLocation(lat: 40.0, lon: -74.0, timestamp: Date())
        let exp = expectation(description: "location")
        mockLocation.simulateLocation(loc)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        vm.stopRun()

        XCTAssertNotNil(vm.completedRun)
        XCTAssertNil(vm.completedRun?.namedRoute)
    }

    // MARK: - Countdown

    func testCountdownTransitionsFromIdle() {
        XCTAssertEqual(vm.runState, .idle)
        vm.startCountdown()
        XCTAssertEqual(vm.runState, .countdown)
        XCTAssertEqual(vm.countdownSeconds, 10)
        XCTAssertTrue(mockLocation.startTrackingCalled)
    }

    func testCountdownDoesNotAccumulateElapsedOrDistance() {
        vm.startCountdown()
        XCTAssertEqual(vm.elapsedSeconds, 0)
        XCTAssertEqual(vm.totalDistanceMeters, 0)

        // Wait a tick
        let exp = expectation(description: "Countdown tick")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3)

        // Still should not have accumulated anything
        XCTAssertEqual(vm.elapsedSeconds, 0)
        XCTAssertEqual(vm.totalDistanceMeters, 0)
        XCTAssertLessThan(vm.countdownSeconds, 10)
    }

    func testCancelCountdownReturnsToIdle() {
        vm.startCountdown()
        XCTAssertEqual(vm.runState, .countdown)

        vm.cancelCountdown()
        XCTAssertEqual(vm.runState, .idle)
        XCTAssertEqual(vm.countdownSeconds, 10)
        XCTAssertTrue(mockLocation.stopTrackingCalled)
    }

    func testStartRunNowFromCountdown() {
        vm.startCountdown()
        XCTAssertEqual(vm.runState, .countdown)

        vm.startRunNow()
        XCTAssertEqual(vm.runState, .active)
        XCTAssertTrue(mockMotion.startCalled)
    }

    // MARK: - Cool Down

    func testToggleCoolDownAccumulators() {
        vm.startRunNow()

        let baseTime = Date()
        let loc1 = makeLocation(lat: 37.0, lon: -122.0, timestamp: baseTime)
        mockLocation.simulateLocation(loc1)

        let exp1 = expectation(description: "First location")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp1.fulfill() }
        wait(for: [exp1], timeout: 1)

        // Toggle cool-down on
        vm.toggleCoolDown()
        XCTAssertTrue(vm.isCoolDownActive)

        // Simulate location update while cool-down is active
        let loc2 = makeLocation(lat: 37.001, lon: -122.0, timestamp: baseTime.addingTimeInterval(30))
        mockLocation.simulateLocation(loc2)

        let exp2 = expectation(description: "Second location")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp2.fulfill() }
        wait(for: [exp2], timeout: 1)

        // Wait for timer ticks to accumulate cool-down duration
        let exp3 = expectation(description: "Timer ticks")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { exp3.fulfill() }
        wait(for: [exp3], timeout: 4)

        // Cool-down distance should have accumulated
        XCTAssertGreaterThan(vm.totalDistanceMeters, 100)
        // The distance was accumulated while cool-down was active, so cool-down distance should match total
        XCTAssertEqual(vm.totalDistanceMeters, vm.totalDistanceMeters - vm.runningOnlyDistanceMeters, accuracy: 1.0)

        // Toggle cool-down off
        vm.toggleCoolDown()
        XCTAssertFalse(vm.isCoolDownActive)

        // Simulate another location update while cool-down is off
        let loc3 = makeLocation(lat: 37.002, lon: -122.0, timestamp: baseTime.addingTimeInterval(60))
        mockLocation.simulateLocation(loc3)

        let exp4 = expectation(description: "Third location")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp4.fulfill() }
        wait(for: [exp4], timeout: 1)

        // Running-only distance should now be greater than 0 (the loc3 distance)
        XCTAssertGreaterThan(vm.runningOnlyDistanceMeters, 0)
    }

    func testCoolDownStopRunPopulatesRunFields() {
        vm.startRunNow()

        // Toggle cool-down on
        vm.toggleCoolDown()
        XCTAssertTrue(vm.isCoolDownActive)

        let baseTime = Date()
        let loc1 = makeLocation(lat: 37.0, lon: -122.0, timestamp: baseTime)
        mockLocation.simulateLocation(loc1)

        let exp1 = expectation(description: "Location")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp1.fulfill() }
        wait(for: [exp1], timeout: 1)

        let loc2 = makeLocation(lat: 37.001, lon: -122.0, timestamp: baseTime.addingTimeInterval(30))
        mockLocation.simulateLocation(loc2)

        let exp2 = expectation(description: "Location 2")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp2.fulfill() }
        wait(for: [exp2], timeout: 1)

        // Wait for some timer ticks
        let exp3 = expectation(description: "Timer")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { exp3.fulfill() }
        wait(for: [exp3], timeout: 4)

        vm.stopRun()

        XCTAssertNotNil(vm.completedRun)
        let run = vm.completedRun!
        XCTAssertTrue(run.hasCoolDown)
        XCTAssertGreaterThan(run.coolDownDistanceMeters, 0)
        XCTAssertGreaterThan(run.coolDownDurationSeconds, 0)
    }

    func testCoolDownResetOnNewRun() {
        vm.startRunNow()
        vm.toggleCoolDown()

        let baseTime = Date()
        let loc1 = makeLocation(lat: 37.0, lon: -122.0, timestamp: baseTime)
        mockLocation.simulateLocation(loc1)
        let loc2 = makeLocation(lat: 37.001, lon: -122.0, timestamp: baseTime.addingTimeInterval(30))
        mockLocation.simulateLocation(loc2)

        let exp1 = expectation(description: "Process")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { exp1.fulfill() }
        wait(for: [exp1], timeout: 1)

        vm.stopRun()

        // Start a new run — accumulators should be reset
        vm.startRunNow()
        XCTAssertFalse(vm.isCoolDownActive)
        XCTAssertEqual(vm.runningOnlyDistanceMeters, 0)
        XCTAssertEqual(vm.runningOnlyDurationSeconds, 0)
    }

    func testNoCoolDownMeansRunFieldsFalse() {
        vm.startRunNow()

        let loc = makeLocation(lat: 37.0, lon: -122.0, timestamp: Date())
        mockLocation.simulateLocation(loc)

        let exp = expectation(description: "Location")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        vm.stopRun()

        XCTAssertNotNil(vm.completedRun)
        XCTAssertFalse(vm.completedRun!.hasCoolDown)
        XCTAssertEqual(vm.completedRun!.coolDownDistanceMeters, 0)
        XCTAssertEqual(vm.completedRun!.coolDownDurationSeconds, 0)
    }

    // MARK: - Checkpoints

    func testDropCheckpointCreatesModels() {
        let route = NamedRoute(name: "Test Route")
        vm.selectedNamedRoute = route
        vm.startRunNow()

        // Simulate user location
        let loc = makeLocation(lat: 37.0, lon: -122.0, timestamp: Date())
        mockLocation.simulateLocation(loc)

        let exp = expectation(description: "Location")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        vm.dropCheckpoint()

        XCTAssertEqual(route.checkpoints.count, 1)
        XCTAssertEqual(route.checkpoints.first?.label, "Checkpoint 1")
        XCTAssertNotNil(vm.latestCheckpointResult)
        XCTAssertNil(vm.latestCheckpointResult?.delta) // defining run, no delta
    }

    func testCheckpointProximityDetection() {
        let route = NamedRoute(name: "Proximity Route")
        let checkpoint = RouteCheckpoint(
            latitude: 37.001,
            longitude: -122.0,
            label: "CP1",
            order: 0,
            namedRoute: route
        )
        route.checkpoints = [checkpoint]
        vm.selectedNamedRoute = route
        vm.startRunNow()

        XCTAssertEqual(vm.nextCheckpointIndex, 0)

        let baseTime = Date()
        // First location (far from checkpoint)
        let loc1 = makeLocation(lat: 37.0, lon: -122.0, timestamp: baseTime)
        mockLocation.simulateLocation(loc1)

        let exp1 = expectation(description: "Loc1")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp1.fulfill() }
        wait(for: [exp1], timeout: 1)

        // Approach checkpoint — within 10m (~5.5m away)
        let loc2 = makeLocation(lat: 37.00105, lon: -122.0, timestamp: baseTime.addingTimeInterval(30))
        mockLocation.simulateLocation(loc2)

        let exp2 = expectation(description: "Loc2")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp2.fulfill() }
        wait(for: [exp2], timeout: 1)

        // Should not trigger yet — runner hasn't departed
        XCTAssertEqual(vm.nextCheckpointIndex, 0)

        // Depart from checkpoint — move away past departure threshold (~10m from checkpoint, ~4.5m departure)
        let loc3 = makeLocation(lat: 37.00109, lon: -122.0, timestamp: baseTime.addingTimeInterval(35))
        mockLocation.simulateLocation(loc3)

        let exp3 = expectation(description: "Loc3")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp3.fulfill() }
        wait(for: [exp3], timeout: 1)

        XCTAssertEqual(vm.nextCheckpointIndex, 1)
        XCTAssertNotNil(vm.latestCheckpointResult)
    }

    func testCheckpointDeltaComputation() {
        let route = NamedRoute(name: "Delta Route")
        let checkpoint = RouteCheckpoint(
            latitude: 37.001,
            longitude: -122.0,
            label: "CP1",
            order: 0,
            namedRoute: route
        )
        route.checkpoints = [checkpoint]

        // Create a benchmark run with results
        let benchmarkRun = Run(startDate: Date(), distanceMeters: 5000, durationSeconds: 1800)
        benchmarkRun.namedRoute = route
        route.runs = [benchmarkRun]
        route.benchmarkRunID = benchmarkRun.id

        let benchmarkResult = RunCheckpointResult(
            elapsedSeconds: 120, // 2 minutes at this checkpoint
            cumulativeDistanceMeters: 500,
            checkpoint: checkpoint,
            run: benchmarkRun
        )
        benchmarkRun.checkpointResults = [benchmarkResult]

        vm.selectedNamedRoute = route
        vm.startRunNow()

        let baseTime = Date()
        let loc1 = makeLocation(lat: 37.0, lon: -122.0, timestamp: baseTime)
        mockLocation.simulateLocation(loc1)

        let exp1 = expectation(description: "Loc1")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp1.fulfill() }
        wait(for: [exp1], timeout: 1)

        // Wait for some elapsed time
        let exp2 = expectation(description: "Timer")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { exp2.fulfill() }
        wait(for: [exp2], timeout: 4)

        // Approach checkpoint (~5.5m away)
        let loc2 = makeLocation(lat: 37.00105, lon: -122.0, timestamp: baseTime.addingTimeInterval(30))
        mockLocation.simulateLocation(loc2)

        let exp3 = expectation(description: "Loc2")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp3.fulfill() }
        wait(for: [exp3], timeout: 1)

        // Depart from checkpoint (~10m away, triggers detection)
        let loc3 = makeLocation(lat: 37.00109, lon: -122.0, timestamp: baseTime.addingTimeInterval(35))
        mockLocation.simulateLocation(loc3)

        let exp4 = expectation(description: "Loc3")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp4.fulfill() }
        wait(for: [exp4], timeout: 1)

        // Delta should be current elapsed - 120 (benchmark time)
        XCTAssertNotNil(vm.latestCheckpointResult?.delta)
    }

    func testNoCheckpointLogicDuringFreeRun() {
        vm.selectedNamedRoute = nil
        vm.startRunNow()

        let loc = makeLocation(lat: 37.0, lon: -122.0, timestamp: Date())
        mockLocation.simulateLocation(loc)

        let exp = expectation(description: "Location")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        XCTAssertEqual(vm.nextCheckpointIndex, 0)
        XCTAssertTrue(vm.routeCheckpoints.isEmpty)
        XCTAssertNil(vm.latestCheckpointResult)
    }

    func testStopRunAppendsCheckpointResults() {
        let route = NamedRoute(name: "Stop Route")
        vm.selectedNamedRoute = route
        vm.startRunNow()

        let loc = makeLocation(lat: 37.0, lon: -122.0, timestamp: Date())
        mockLocation.simulateLocation(loc)

        let exp = expectation(description: "Location")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        vm.dropCheckpoint()
        vm.stopRun()

        XCTAssertNotNil(vm.completedRun)
        XCTAssertEqual(vm.completedRun!.checkpointResults.count, 1)
    }

    // MARK: - Duplicate Checkpoint Prevention

    func testManualDropThenProximityDoesNotDuplicate() {
        let route = NamedRoute(name: "Dup Route")
        vm.selectedNamedRoute = route
        vm.startRunNow()

        // Simulate user location at the checkpoint position
        let cpLat = 37.001
        let cpLon = -122.0
        let baseTime = Date()
        let loc1 = makeLocation(lat: 37.0, lon: cpLon, timestamp: baseTime)
        mockLocation.simulateLocation(loc1)

        let exp1 = expectation(description: "Loc1")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp1.fulfill() }
        wait(for: [exp1], timeout: 1)

        // Manually drop a checkpoint at cpLat
        let loc2 = makeLocation(lat: cpLat, lon: cpLon, timestamp: baseTime.addingTimeInterval(10))
        mockLocation.simulateLocation(loc2)

        let exp2 = expectation(description: "Loc2")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp2.fulfill() }
        wait(for: [exp2], timeout: 1)

        vm.dropCheckpoint()

        // Now simulate proximity detection by moving near the same checkpoint
        let loc3 = makeLocation(lat: cpLat + 0.00001, lon: cpLon, timestamp: baseTime.addingTimeInterval(20))
        mockLocation.simulateLocation(loc3)

        let exp3 = expectation(description: "Loc3")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp3.fulfill() }
        wait(for: [exp3], timeout: 1)

        // Stop and check — should only have 1 checkpoint result, not 2
        vm.stopRun()

        XCTAssertNotNil(vm.completedRun)
        XCTAssertEqual(vm.completedRun!.checkpointResults.count, 1,
                       "Proximity detection should not create a duplicate result for a manually dropped checkpoint")
    }

    func testFreeRunDropCheckpointCreatesResult() {
        vm.selectedNamedRoute = nil
        vm.startRunNow()

        let loc = makeLocation(lat: 37.0, lon: -122.0, timestamp: Date())
        mockLocation.simulateLocation(loc)

        let exp = expectation(description: "Location")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        vm.dropCheckpoint()

        XCTAssertEqual(vm.pendingFreeRunCheckpoints.count, 1)
        XCTAssertEqual(vm.routeCheckpoints.count, 1)
        XCTAssertNotNil(vm.latestCheckpointResult)

        vm.stopRun()
        XCTAssertEqual(vm.completedRun!.checkpointResults.count, 1)
    }

    // MARK: - Loop Route Detection

    func testLoopRouteAutoDetection() {
        let route = NamedRoute(name: "Track")
        // First and last checkpoints within 50m of each other (same point)
        let cp1 = RouteCheckpoint(latitude: 37.0, longitude: -122.0, label: "Start/Finish", order: 0, namedRoute: route)
        let cp2 = RouteCheckpoint(latitude: 37.001, longitude: -122.0, label: "CP2", order: 1, namedRoute: route)
        let cp3 = RouteCheckpoint(latitude: 37.001, longitude: -122.001, label: "CP3", order: 2, namedRoute: route)
        let cp4 = RouteCheckpoint(latitude: 37.0, longitude: -122.0001, label: "Finish", order: 3, namedRoute: route)
        route.checkpoints = [cp1, cp2, cp3, cp4]

        vm.selectedNamedRoute = route
        vm.startRunNow()

        XCTAssertTrue(vm.isLoopRoute, "Route with start/finish within 50m should be detected as a loop")
    }

    func testNonLoopRouteDetection() {
        let route = NamedRoute(name: "Out and Back")
        let cp1 = RouteCheckpoint(latitude: 37.0, longitude: -122.0, label: "Start", order: 0, namedRoute: route)
        let cp2 = RouteCheckpoint(latitude: 37.01, longitude: -122.0, label: "Turnaround", order: 1, namedRoute: route)
        route.checkpoints = [cp1, cp2]

        vm.selectedNamedRoute = route
        vm.startRunNow()

        XCTAssertFalse(vm.isLoopRoute, "Route with distant start/finish should not be a loop")
    }

    func testManualLoopRouteFlag() {
        let route = NamedRoute(name: "Manual Loop", isLoopRoute: true)
        let cp1 = RouteCheckpoint(latitude: 37.0, longitude: -122.0, label: "CP1", order: 0, namedRoute: route)
        let cp2 = RouteCheckpoint(latitude: 37.01, longitude: -122.0, label: "CP2", order: 1, namedRoute: route)
        route.checkpoints = [cp1, cp2]

        vm.selectedNamedRoute = route
        vm.startRunNow()

        XCTAssertTrue(vm.isLoopRoute, "Route with isLoopRoute=true should be treated as a loop")
    }

    // MARK: - Multi-Lap Support

    func testLapWraparound() {
        let route = NamedRoute(name: "Track", isLoopRoute: true)
        let cp1 = RouteCheckpoint(latitude: 37.001, longitude: -122.0, label: "CP1", order: 0, namedRoute: route)
        let cp2 = RouteCheckpoint(latitude: 37.002, longitude: -122.0, label: "CP2", order: 1, namedRoute: route)
        route.checkpoints = [cp1, cp2]

        vm.selectedNamedRoute = route
        vm.startRunNow()

        XCTAssertEqual(vm.currentLap, 0)
        XCTAssertEqual(vm.nextCheckpointIndex, 0)

        let baseTime = Date()

        // Pass CP1 (lap 0)
        simulateCheckpointPass(cpLat: 37.001, cpLon: -122.0, baseTime: baseTime, offset: 0)
        XCTAssertEqual(vm.nextCheckpointIndex, 1)

        // Pass CP2 (lap 0) — nextCheckpointIndex goes past array
        simulateCheckpointPass(cpLat: 37.002, cpLon: -122.0, baseTime: baseTime, offset: 40)

        // completeLap fires on the next location update (when guard finds index past array)
        let triggerLoc = makeLocation(lat: 37.0, lon: -122.0, timestamp: baseTime.addingTimeInterval(65))
        mockLocation.simulateLocation(triggerLoc)
        waitForLocation()

        XCTAssertEqual(vm.currentLap, 1, "Should have advanced to lap 1")
        XCTAssertEqual(vm.nextCheckpointIndex, 0, "Should wrap back to first checkpoint")
        XCTAssertEqual(vm.lapTimes.count, 1, "Should have recorded one lap time")
    }

    func testCheckpointResultsHaveLapNumber() {
        let route = NamedRoute(name: "Track", isLoopRoute: true)
        let cp1 = RouteCheckpoint(latitude: 37.001, longitude: -122.0, label: "CP1", order: 0, namedRoute: route)
        route.checkpoints = [cp1]

        vm.selectedNamedRoute = route
        vm.startRunNow()

        let baseTime = Date()

        // Pass CP1 on lap 0
        simulateCheckpointPass(cpLat: 37.001, cpLon: -122.0, baseTime: baseTime, offset: 0)

        // Trigger lap wrap with another location update
        let triggerLoc1 = makeLocation(lat: 37.0, lon: -122.0, timestamp: baseTime.addingTimeInterval(25))
        mockLocation.simulateLocation(triggerLoc1)
        waitForLocation()

        // Should now be on lap 1
        XCTAssertEqual(vm.currentLap, 1)

        // Pass CP1 on lap 1
        simulateCheckpointPass(cpLat: 37.001, cpLon: -122.0, baseTime: baseTime, offset: 60)

        vm.stopRun()

        let results = vm.completedRun!.checkpointResults.sorted { $0.elapsedSeconds < $1.elapsedSeconds }
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].lapNumber, 0)
        XCTAssertEqual(results[1].lapNumber, 1)
    }

    func testRunTotalLapsOnStop() {
        let route = NamedRoute(name: "Track", isLoopRoute: true)
        let cp1 = RouteCheckpoint(latitude: 37.001, longitude: -122.0, label: "CP1", order: 0, namedRoute: route)
        route.checkpoints = [cp1]

        vm.selectedNamedRoute = route
        vm.startRunNow()

        let baseTime = Date()

        // Complete 3 full laps (pass checkpoint + trigger lap wrap each time)
        for lap in 0..<3 {
            let offset = Double(lap) * 60
            simulateCheckpointPass(cpLat: 37.001, cpLon: -122.0, baseTime: baseTime, offset: offset)
            // Trigger lap wrap
            let triggerLoc = makeLocation(lat: 37.0, lon: -122.0, timestamp: baseTime.addingTimeInterval(offset + 25))
            mockLocation.simulateLocation(triggerLoc)
            waitForLocation()
        }

        vm.stopRun()
        XCTAssertEqual(vm.completedRun!.totalLaps, 3)
    }

    // MARK: - Direction Gate

    func testDirectionGateRejectsWrongDirection() {
        let route = NamedRoute(name: "Direction Route")
        let cp = RouteCheckpoint(
            latitude: 37.001,
            longitude: -122.0,
            label: "CP1",
            order: 0,
            expectedApproachBearing: 0, // expect heading north
            namedRoute: route
        )
        route.checkpoints = [cp]

        vm.selectedNamedRoute = route
        vm.startRunNow()

        let baseTime = Date()

        // Approach from the south (wrong direction — heading south, course=180)
        let loc1 = makeLocation(lat: 37.0, lon: -122.0, timestamp: baseTime)
        mockLocation.simulateLocation(loc1)
        waitForLocation()

        let loc2 = makeLocation(lat: 37.00105, lon: -122.0, course: 180, timestamp: baseTime.addingTimeInterval(30))
        mockLocation.simulateLocation(loc2)
        waitForLocation()

        let loc3 = makeLocation(lat: 37.00109, lon: -122.0, course: 180, timestamp: baseTime.addingTimeInterval(35))
        mockLocation.simulateLocation(loc3)
        waitForLocation()

        XCTAssertEqual(vm.nextCheckpointIndex, 0, "Should not trigger — wrong direction")
    }

    func testDirectionGateAcceptsCorrectDirection() {
        let route = NamedRoute(name: "Direction Route")
        let cp = RouteCheckpoint(
            latitude: 37.001,
            longitude: -122.0,
            label: "CP1",
            order: 0,
            expectedApproachBearing: 0, // expect heading north
            namedRoute: route
        )
        route.checkpoints = [cp]

        vm.selectedNamedRoute = route
        vm.startRunNow()

        let baseTime = Date()

        let loc1 = makeLocation(lat: 37.0, lon: -122.0, timestamp: baseTime)
        mockLocation.simulateLocation(loc1)
        waitForLocation()

        // Heading north (course=30, within 60° tolerance of 0)
        let loc2 = makeLocation(lat: 37.00105, lon: -122.0, course: 30, timestamp: baseTime.addingTimeInterval(30))
        mockLocation.simulateLocation(loc2)
        waitForLocation()

        let loc3 = makeLocation(lat: 37.00109, lon: -122.0, course: 30, timestamp: baseTime.addingTimeInterval(35))
        mockLocation.simulateLocation(loc3)
        waitForLocation()

        XCTAssertEqual(vm.nextCheckpointIndex, 1, "Should trigger — correct direction")
    }

    func testDirectionFallbackWhenCourseInvalid() {
        let route = NamedRoute(name: "Fallback Route")
        let cp = RouteCheckpoint(
            latitude: 37.001,
            longitude: -122.0,
            label: "CP1",
            order: 0,
            expectedApproachBearing: 0,
            namedRoute: route
        )
        route.checkpoints = [cp]

        vm.selectedNamedRoute = route
        vm.startRunNow()

        let baseTime = Date()

        let loc1 = makeLocation(lat: 37.0, lon: -122.0, timestamp: baseTime)
        mockLocation.simulateLocation(loc1)
        waitForLocation()

        // Course = -1 (invalid) — should fall back to proximity-only
        let loc2 = makeLocation(lat: 37.00105, lon: -122.0, course: -1, timestamp: baseTime.addingTimeInterval(30))
        mockLocation.simulateLocation(loc2)
        waitForLocation()

        let loc3 = makeLocation(lat: 37.00109, lon: -122.0, course: -1, timestamp: baseTime.addingTimeInterval(35))
        mockLocation.simulateLocation(loc3)
        waitForLocation()

        XCTAssertEqual(vm.nextCheckpointIndex, 1, "Should trigger via proximity fallback when course is invalid")
    }

    func testDirectionFallbackWhenBearingNil() {
        let route = NamedRoute(name: "No Bearing Route")
        let cp = RouteCheckpoint(
            latitude: 37.001,
            longitude: -122.0,
            label: "CP1",
            order: 0,
            namedRoute: route
        )
        route.checkpoints = [cp]

        vm.selectedNamedRoute = route
        vm.startRunNow()

        let baseTime = Date()

        let loc1 = makeLocation(lat: 37.0, lon: -122.0, timestamp: baseTime)
        mockLocation.simulateLocation(loc1)
        waitForLocation()

        // Heading opposite direction, but no bearing set — should still trigger
        let loc2 = makeLocation(lat: 37.00105, lon: -122.0, course: 180, timestamp: baseTime.addingTimeInterval(30))
        mockLocation.simulateLocation(loc2)
        waitForLocation()

        let loc3 = makeLocation(lat: 37.00109, lon: -122.0, course: 180, timestamp: baseTime.addingTimeInterval(35))
        mockLocation.simulateLocation(loc3)
        waitForLocation()

        XCTAssertEqual(vm.nextCheckpointIndex, 1, "Should trigger via proximity when bearing is nil")
    }

    // MARK: - Helpers

    /// Simulate approaching and departing a checkpoint to trigger detection.
    private func simulateCheckpointPass(cpLat: Double, cpLon: Double, baseTime: Date, offset: Double) {
        // Far approach
        let far = makeLocation(lat: cpLat - 0.001, lon: cpLon, timestamp: baseTime.addingTimeInterval(offset))
        mockLocation.simulateLocation(far)
        waitForLocation()

        // Close approach (~5.5m away)
        let close = makeLocation(lat: cpLat + 0.00005, lon: cpLon, timestamp: baseTime.addingTimeInterval(offset + 15))
        mockLocation.simulateLocation(close)
        waitForLocation()

        // Depart (~10m away, triggers detection)
        let depart = makeLocation(lat: cpLat + 0.00009, lon: cpLon, timestamp: baseTime.addingTimeInterval(offset + 20))
        mockLocation.simulateLocation(depart)
        waitForLocation()
    }

    private func waitForLocation() {
        let exp = expectation(description: "loc")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)
    }
}
