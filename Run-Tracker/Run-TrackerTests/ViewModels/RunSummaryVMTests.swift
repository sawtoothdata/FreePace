//
//  RunSummaryVMTests.swift
//  Run-TrackerTests
//

import XCTest
@testable import Run_Tracker

final class RunSummaryVMTests: XCTestCase {

    // MARK: - Helper

    private func makeRun(
        distanceMeters: Double = 5000,
        durationSeconds: Double = 1800,
        elevationGainMeters: Double = 50,
        elevationLossMeters: Double = 30,
        averageCadence: Double? = 164,
        totalSteps: Int = 4920,
        splits: [Split] = [],
        routePoints: [RoutePoint] = [],
        namedRoute: NamedRoute? = nil
    ) -> Run {
        Run(
            startDate: Date(timeIntervalSince1970: 1741334400), // Mar 7, 2025
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds,
            elevationGainMeters: elevationGainMeters,
            elevationLossMeters: elevationLossMeters,
            averageCadence: averageCadence,
            totalSteps: totalSteps,
            namedRoute: namedRoute,
            splits: splits,
            routePoints: routePoints
        )
    }

    // MARK: - Basic Display Values

    func testFormattedDistance_Imperial() {
        let run = makeRun(distanceMeters: 8046.72) // ~5 miles
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)
        XCTAssertEqual(vm.formattedDistance, "5.00 mi")
    }

    func testFormattedDistance_Metric() {
        let run = makeRun(distanceMeters: 5000)
        let vm = RunSummaryVM(run: run, unitSystem: .metric)
        XCTAssertEqual(vm.formattedDistance, "5.00 km")
    }

    func testFormattedDuration() {
        let run = makeRun(durationSeconds: 3723) // 1:02:03
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)
        XCTAssertEqual(vm.formattedDuration, "01:02:03")
    }

    func testFormattedAvgPace_Imperial() {
        // 1609.344m in 480s = 8'00"/mi
        let run = makeRun(distanceMeters: 1609.344, durationSeconds: 480)
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)
        XCTAssertEqual(vm.formattedAvgPace, "8'00\" /mi")
    }

    func testFormattedAvgPace_ZeroDistance() {
        let run = makeRun(distanceMeters: 0, durationSeconds: 100)
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)
        XCTAssertEqual(vm.formattedAvgPace, "— —")
    }

    func testFormattedAvgCadence() {
        let run = makeRun(averageCadence: 164)
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)
        XCTAssertEqual(vm.formattedAvgCadence, "164 spm")
    }

    func testFormattedAvgCadence_Nil() {
        let run = makeRun(averageCadence: nil)
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)
        XCTAssertEqual(vm.formattedAvgCadence, "—")
    }

    func testFormattedElevation_Imperial() {
        // 30.48m = 100ft
        let run = makeRun(elevationGainMeters: 30.48, elevationLossMeters: 15.24)
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)
        XCTAssertEqual(vm.formattedElevationGain, "100 ft")
        XCTAssertEqual(vm.formattedElevationLoss, "50 ft")
    }

    func testFormattedElevation_Metric() {
        let run = makeRun(elevationGainMeters: 50, elevationLossMeters: 30)
        let vm = RunSummaryVM(run: run, unitSystem: .metric)
        XCTAssertEqual(vm.formattedElevationGain, "50 m")
        XCTAssertEqual(vm.formattedElevationLoss, "30 m")
    }

    func testTotalSteps() {
        let run = makeRun(totalSteps: 4920)
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)
        XCTAssertEqual(vm.formattedTotalSteps, "4920")
        XCTAssertEqual(vm.totalSteps, 4920)
    }

    // MARK: - Split Data

    func testSplitData_SortedByIndex() {
        let split1 = Split(splitIndex: 1, distanceMeters: 1609.344, durationSeconds: 462,
                           elevationGainMeters: 10, elevationLossMeters: 5,
                           averageCadence: 164, startDate: Date(), endDate: Date())
        let split2 = Split(splitIndex: 2, distanceMeters: 1609.344, durationSeconds: 475,
                           elevationGainMeters: 15, elevationLossMeters: 8,
                           averageCadence: 161, startDate: Date(), endDate: Date())
        // Add in reverse order
        let run = makeRun(splits: [split2, split1])
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)

        XCTAssertEqual(vm.splitData.count, 2)
        XCTAssertEqual(vm.splitData[0].index, 1)
        XCTAssertEqual(vm.splitData[1].index, 2)
    }

    func testSplitData_PaceCalculation() {
        let split = Split(splitIndex: 1, distanceMeters: 1609.344, durationSeconds: 480,
                          startDate: Date(), endDate: Date())
        let run = makeRun(splits: [split])
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)

        let splitDisplay = vm.splitData[0]
        // pace = 480 / 1609.344 ≈ 0.2982 s/m
        XCTAssertEqual(splitDisplay.paceSecondsPerMeter, 480.0 / 1609.344, accuracy: 0.001)
    }

    func testFastestAndSlowestSplit() {
        let fast = Split(splitIndex: 1, distanceMeters: 1609.344, durationSeconds: 420,
                         startDate: Date(), endDate: Date())
        let slow = Split(splitIndex: 2, distanceMeters: 1609.344, durationSeconds: 510,
                         startDate: Date(), endDate: Date())
        let mid = Split(splitIndex: 3, distanceMeters: 1609.344, durationSeconds: 465,
                        startDate: Date(), endDate: Date())
        let run = makeRun(splits: [fast, slow, mid])
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)

        XCTAssertEqual(vm.fastestSplitIndex, 1)
        XCTAssertEqual(vm.slowestSplitIndex, 2)
    }

    func testFastestSlowest_IgnoresPartialSplits() {
        let full1 = Split(splitIndex: 1, distanceMeters: 1609.344, durationSeconds: 480,
                          startDate: Date(), endDate: Date())
        let full2 = Split(splitIndex: 2, distanceMeters: 1609.344, durationSeconds: 500,
                          startDate: Date(), endDate: Date())
        let partial = Split(splitIndex: 3, distanceMeters: 800, durationSeconds: 200,
                            startDate: Date(), endDate: Date(), isPartial: true)
        let run = makeRun(splits: [full1, full2, partial])
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)

        XCTAssertEqual(vm.fastestSplitIndex, 1)
        XCTAssertEqual(vm.slowestSplitIndex, 2)
        XCTAssertEqual(vm.splitData.count, 3) // partial still in data
    }

    func testFastestSlowest_NilWhenOnlyOneSplit() {
        let split = Split(splitIndex: 1, distanceMeters: 1609.344, durationSeconds: 480,
                          startDate: Date(), endDate: Date())
        let run = makeRun(splits: [split])
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)

        XCTAssertNil(vm.fastestSplitIndex)
        XCTAssertNil(vm.slowestSplitIndex)
    }

    func testNoSplits() {
        let run = makeRun()
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)

        XCTAssertTrue(vm.splitData.isEmpty)
        XCTAssertNil(vm.fastestSplitIndex)
        XCTAssertNil(vm.slowestSplitIndex)
    }

    // MARK: - Elevation Profile

    func testElevationProfile_SortedByDistance() {
        let p1 = RoutePoint(latitude: 0, longitude: 0, altitude: 100, smoothedAltitude: 100,
                            horizontalAccuracy: 5, speed: 3, distanceFromStart: 500)
        let p2 = RoutePoint(latitude: 0, longitude: 0, altitude: 110, smoothedAltitude: 110,
                            horizontalAccuracy: 5, speed: 3, distanceFromStart: 1000)
        let p3 = RoutePoint(latitude: 0, longitude: 0, altitude: 105, smoothedAltitude: 105,
                            horizontalAccuracy: 5, speed: 3, distanceFromStart: 200)
        let run = makeRun(routePoints: [p1, p2, p3])
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)

        XCTAssertEqual(vm.elevationProfilePoints.count, 3)
        XCTAssertEqual(vm.elevationProfilePoints[0].distanceMeters, 200)
        XCTAssertEqual(vm.elevationProfilePoints[1].distanceMeters, 500)
        XCTAssertEqual(vm.elevationProfilePoints[2].distanceMeters, 1000)
    }

    func testElevationProfile_UsesSmoothedAltitude() {
        let p = RoutePoint(latitude: 0, longitude: 0, altitude: 100, smoothedAltitude: 98,
                           horizontalAccuracy: 5, speed: 3, distanceFromStart: 0)
        let run = makeRun(routePoints: [p])
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)

        XCTAssertEqual(vm.elevationProfilePoints[0].elevationMeters, 98)
    }

    func testElevationProfile_EmptyRoutePoints() {
        let run = makeRun()
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)
        XCTAssertTrue(vm.elevationProfilePoints.isEmpty)
    }

    // MARK: - Route Name

    func testRouteName_Present() {
        let route = NamedRoute(name: "Morning Loop")
        let run = makeRun(namedRoute: route)
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)
        XCTAssertEqual(vm.routeName, "Morning Loop")
    }

    func testRouteName_Nil() {
        let run = makeRun()
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)
        XCTAssertNil(vm.routeName)
    }

    // MARK: - Cool Down Stats

    func testRunningOnlyStats_MixedSplits() {
        // 2 running splits + 1 cool-down split
        let runningSplit1 = Split(splitIndex: 1, distanceMeters: 1609.344, durationSeconds: 480,
                                  elevationGainMeters: 10, elevationLossMeters: 5,
                                  startDate: Date(), endDate: Date())
        let runningSplit2 = Split(splitIndex: 2, distanceMeters: 1609.344, durationSeconds: 490,
                                  elevationGainMeters: 15, elevationLossMeters: 8,
                                  startDate: Date(), endDate: Date())
        let coolDownSplit = Split(splitIndex: 3, distanceMeters: 800, durationSeconds: 300,
                                  elevationGainMeters: 5, elevationLossMeters: 3,
                                  startDate: Date(), endDate: Date(), isPartial: true, isCoolDown: true)

        let run = Run(
            distanceMeters: 4018.688,  // 1609.344 * 2 + 800
            durationSeconds: 1270,     // 480 + 490 + 300
            elevationGainMeters: 30,
            elevationLossMeters: 16,
            splits: [runningSplit1, runningSplit2, coolDownSplit]
        )
        run.hasCoolDown = true
        run.coolDownDistanceMeters = 800
        run.coolDownDurationSeconds = 300

        let vm = RunSummaryVM(run: run, unitSystem: .imperial)

        // Running-only splits should exclude cool-down
        XCTAssertEqual(vm.runningOnlySplits.count, 2)

        // Running-only distance = total - cool-down
        XCTAssertEqual(vm.runningOnlyDistanceMeters, 3218.688, accuracy: 0.01)

        // Running-only duration = total - cool-down
        XCTAssertEqual(vm.runningOnlyDurationSeconds, 970, accuracy: 0.01)

        // Running-only elevation gain from non-cool-down splits
        XCTAssertEqual(vm.runningOnlyElevationGainMeters, 25, accuracy: 0.01)

        // Running-only pace
        XCTAssertEqual(vm.runningOnlyAveragePaceSecondsPerMeter, 970.0 / 3218.688, accuracy: 0.001)
    }

    func testRunningOnlyStats_NoCoolDown() {
        let split = Split(splitIndex: 1, distanceMeters: 1609.344, durationSeconds: 480,
                          elevationGainMeters: 10, elevationLossMeters: 5,
                          startDate: Date(), endDate: Date())
        let run = makeRun(distanceMeters: 1609.344, durationSeconds: 480,
                          elevationGainMeters: 10, elevationLossMeters: 5, splits: [split])
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)

        // All splits are running splits
        XCTAssertEqual(vm.runningOnlySplits.count, 1)
        XCTAssertEqual(vm.runningOnlyDistanceMeters, 1609.344, accuracy: 0.01)
        XCTAssertEqual(vm.runningOnlyDurationSeconds, 480, accuracy: 0.01)
    }

    func testRunningOnlyStats_ZeroDistance() {
        let run = makeRun(distanceMeters: 0, durationSeconds: 0)
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)
        XCTAssertEqual(vm.runningOnlyAveragePaceSecondsPerMeter, 0)
    }

    // MARK: - Checkpoint Rows

    func testCheckpointRows_WithBenchmark() {
        // Set up route with benchmark
        let route = NamedRoute(name: "Test Route")
        let checkpoint1 = RouteCheckpoint(latitude: 40.0, longitude: -105.0, label: "CP 1", order: 0, namedRoute: route)
        let checkpoint2 = RouteCheckpoint(latitude: 40.01, longitude: -105.01, label: "CP 2", order: 1, namedRoute: route)
        route.checkpoints = [checkpoint1, checkpoint2]

        // Benchmark run
        let benchmarkRun = Run(distanceMeters: 5000, durationSeconds: 1800)
        benchmarkRun.namedRoute = route
        let benchResult1 = RunCheckpointResult(elapsedSeconds: 300, cumulativeDistanceMeters: 1000, checkpoint: checkpoint1, run: benchmarkRun)
        let benchResult2 = RunCheckpointResult(elapsedSeconds: 600, cumulativeDistanceMeters: 2000, checkpoint: checkpoint2, run: benchmarkRun)
        benchmarkRun.checkpointResults = [benchResult1, benchResult2]
        route.benchmarkRunID = benchmarkRun.id
        route.runs = [benchmarkRun]

        // Current run (10s ahead at CP1, 20s behind at CP2)
        let currentRun = Run(distanceMeters: 5000, durationSeconds: 1810)
        currentRun.namedRoute = route
        let result1 = RunCheckpointResult(elapsedSeconds: 290, cumulativeDistanceMeters: 1000, checkpoint: checkpoint1, run: currentRun)
        let result2 = RunCheckpointResult(elapsedSeconds: 620, cumulativeDistanceMeters: 2000, checkpoint: checkpoint2, run: currentRun)
        currentRun.checkpointResults = [result1, result2]
        route.runs.append(currentRun)

        let vm = RunSummaryVM(run: currentRun, unitSystem: .imperial)
        XCTAssertEqual(vm.checkpointRows.count, 2)
        XCTAssertEqual(vm.checkpointRows[0].label, "CP 1")
        XCTAssertEqual(vm.checkpointRows[0].elapsedSeconds, 290)
        XCTAssertEqual(vm.checkpointRows[0].delta!, -10, accuracy: 0.01) // 10s ahead
        XCTAssertEqual(vm.checkpointRows[1].label, "CP 2")
        XCTAssertEqual(vm.checkpointRows[1].delta!, 20, accuracy: 0.01) // 20s behind
    }

    func testCheckpointRows_NoBenchmark() {
        let route = NamedRoute(name: "Test Route")
        let checkpoint = RouteCheckpoint(latitude: 40.0, longitude: -105.0, label: "CP 1", order: 0, namedRoute: route)
        route.checkpoints = [checkpoint]
        // No benchmarkRunID set

        let currentRun = Run(distanceMeters: 5000, durationSeconds: 1800)
        currentRun.namedRoute = route
        let result = RunCheckpointResult(elapsedSeconds: 300, cumulativeDistanceMeters: 1000, checkpoint: checkpoint, run: currentRun)
        currentRun.checkpointResults = [result]
        route.runs = [currentRun]

        let vm = RunSummaryVM(run: currentRun, unitSystem: .imperial)
        XCTAssertEqual(vm.checkpointRows.count, 1)
        XCTAssertEqual(vm.checkpointRows[0].label, "CP 1")
        XCTAssertEqual(vm.checkpointRows[0].elapsedSeconds, 300)
        XCTAssertNil(vm.checkpointRows[0].delta)
    }

    func testCheckpointRows_NoResults() {
        let run = makeRun()
        let vm = RunSummaryVM(run: run, unitSystem: .imperial)
        XCTAssertTrue(vm.checkpointRows.isEmpty)
    }
}
