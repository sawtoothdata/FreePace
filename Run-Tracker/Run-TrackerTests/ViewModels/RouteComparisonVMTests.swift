//
//  RouteComparisonVMTests.swift
//  Run-TrackerTests
//

import XCTest
@testable import Run_Tracker

final class RouteComparisonVMTests: XCTestCase {

    private func makeRun(startDate: Date, splitDurations: [Double]) -> Run {
        let run = Run(
            startDate: startDate,
            endDate: startDate.addingTimeInterval(splitDurations.reduce(0, +)),
            distanceMeters: Double(splitDurations.count) * 1609.344,
            durationSeconds: splitDurations.reduce(0, +),
            elevationGainMeters: 0,
            elevationLossMeters: 0
        )
        for (i, duration) in splitDurations.enumerated() {
            let split = Split(
                splitIndex: i + 1,
                distanceMeters: 1609.344,
                durationSeconds: duration,
                elevationGainMeters: 0,
                elevationLossMeters: 0,
                averageCadence: nil,
                startDate: startDate,
                endDate: startDate.addingTimeInterval(duration),
                isPartial: false
            )
            split.run = run
            run.splits.append(split)
        }
        return run
    }

    // MARK: - Normal Case

    func testCoachDataNormalCase() {
        let route = NamedRoute(name: "Test Route")
        let run1 = makeRun(startDate: Date().addingTimeInterval(-7200), splitDurations: [480, 470, 460])
        let run2 = makeRun(startDate: Date().addingTimeInterval(-3600), splitDurations: [500, 490, 480])
        let run3 = makeRun(startDate: Date(), splitDurations: [460, 450, 440]) // most recent
        run1.namedRoute = route
        run2.namedRoute = route
        run3.namedRoute = route
        route.runs = [run1, run2, run3]

        let vm = RouteComparisonVM()
        vm.loadCoachData(for: route)

        // Last run should be run3 (most recent by startDate)
        XCTAssertEqual(vm.lastRunCumulativeSplitTimes.count, 3)
        XCTAssertEqual(vm.lastRunCumulativeSplitTimes[0], 460, accuracy: 0.01)   // split 1
        XCTAssertEqual(vm.lastRunCumulativeSplitTimes[1], 910, accuracy: 0.01)   // split 1 + 2
        XCTAssertEqual(vm.lastRunCumulativeSplitTimes[2], 1350, accuracy: 0.01)  // split 1 + 2 + 3

        // Average cumulative times: avg of 3 runs at each split
        XCTAssertEqual(vm.averageCumulativeSplitTimes.count, 3)
        let expectedAvg0 = (480.0 + 500.0 + 460.0) / 3.0
        XCTAssertEqual(vm.averageCumulativeSplitTimes[0], expectedAvg0, accuracy: 0.01)

        let cumRun1_2 = 480.0 + 470.0
        let cumRun2_2 = 500.0 + 490.0
        let cumRun3_2 = 460.0 + 450.0
        let expectedAvg1 = (cumRun1_2 + cumRun2_2 + cumRun3_2) / 3.0
        XCTAssertEqual(vm.averageCumulativeSplitTimes[1], expectedAvg1, accuracy: 0.01)
    }

    // MARK: - Runs with Different Split Counts

    func testCoachDataDifferentSplitCounts() {
        let route = NamedRoute(name: "Test Route")
        let run1 = makeRun(startDate: Date().addingTimeInterval(-3600), splitDurations: [480, 470, 460])
        let run2 = makeRun(startDate: Date(), splitDurations: [500, 490]) // only 2 splits
        run1.namedRoute = route
        run2.namedRoute = route
        route.runs = [run1, run2]

        let vm = RouteComparisonVM()
        vm.loadCoachData(for: route)

        // Last run is run2 with 2 splits
        XCTAssertEqual(vm.lastRunCumulativeSplitTimes.count, 2)
        XCTAssertEqual(vm.lastRunCumulativeSplitTimes[0], 500, accuracy: 0.01)
        XCTAssertEqual(vm.lastRunCumulativeSplitTimes[1], 990, accuracy: 0.01)

        // Average should use min count = 2
        XCTAssertEqual(vm.averageCumulativeSplitTimes.count, 2)
    }

    // MARK: - Single Run (last = average)

    func testCoachDataSingleRun() {
        let route = NamedRoute(name: "Solo Route")
        let run = makeRun(startDate: Date(), splitDurations: [420, 430])
        run.namedRoute = route
        route.runs = [run]

        let vm = RouteComparisonVM()
        vm.loadCoachData(for: route)

        XCTAssertEqual(vm.lastRunCumulativeSplitTimes.count, 2)
        XCTAssertEqual(vm.averageCumulativeSplitTimes.count, 2)

        // With one run, last and average should be the same
        XCTAssertEqual(vm.lastRunCumulativeSplitTimes[0], vm.averageCumulativeSplitTimes[0], accuracy: 0.01)
        XCTAssertEqual(vm.lastRunCumulativeSplitTimes[1], vm.averageCumulativeSplitTimes[1], accuracy: 0.01)
    }

    // MARK: - No Runs

    func testCoachDataNoRuns() {
        let route = NamedRoute(name: "Empty Route")

        let vm = RouteComparisonVM()
        vm.loadCoachData(for: route)

        XCTAssertTrue(vm.lastRunCumulativeSplitTimes.isEmpty)
        XCTAssertTrue(vm.averageCumulativeSplitTimes.isEmpty)
        XCTAssertFalse(vm.hasCoachData)
    }

    // MARK: - Reset Clears Coach Data

    func testResetClearsCoachData() {
        let route = NamedRoute(name: "Test Route")
        let run = makeRun(startDate: Date(), splitDurations: [420])
        run.namedRoute = route
        route.runs = [run]

        let vm = RouteComparisonVM()
        vm.loadCoachData(for: route)
        XCTAssertTrue(vm.hasCoachData)

        vm.reset()
        XCTAssertFalse(vm.hasCoachData)
        XCTAssertTrue(vm.lastRunCumulativeSplitTimes.isEmpty)
        XCTAssertTrue(vm.averageCumulativeSplitTimes.isEmpty)
    }
}
