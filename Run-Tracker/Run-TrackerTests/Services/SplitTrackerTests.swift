//
//  SplitTrackerTests.swift
//  Run-TrackerTests
//

import XCTest
import Combine
@testable import Run_Tracker

final class SplitTrackerTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []
    private let startDate = Date(timeIntervalSince1970: 1000)

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - Single Split (Imperial)

    func testSingleSplitImperial() {
        let tracker = SplitTracker(unitSystem: .imperial, startDate: startDate)
        var receivedSplits: [SplitSnapshot] = []

        tracker.splitPublisher.sink { split in
            receivedSplits.append(split)
        }.store(in: &cancellables)

        // Simulate distance updates approaching 1 mile (1609.344m)
        tracker.updateDistance(
            totalDistanceMeters: 800,
            totalDurationSeconds: 200,
            elevationGainMeters: 10,
            elevationLossMeters: 5,
            currentCadence: 160,
            timeDelta: 200
        )
        XCTAssertEqual(receivedSplits.count, 0, "No split before boundary")

        // Cross the 1-mile mark
        tracker.updateDistance(
            totalDistanceMeters: 1610,
            totalDurationSeconds: 480,
            elevationGainMeters: 25,
            elevationLossMeters: 12,
            currentCadence: 165,
            timeDelta: 280
        )

        XCTAssertEqual(receivedSplits.count, 1)
        let split = receivedSplits[0]
        XCTAssertEqual(split.splitIndex, 1)
        XCTAssertEqual(split.distanceMeters, 1609.344, accuracy: 0.01)
        XCTAssertEqual(split.isPartial, false)
    }

    // MARK: - Multiple Splits

    func testMultipleSplitsImperial() {
        let tracker = SplitTracker(unitSystem: .imperial, startDate: startDate)
        var receivedSplits: [SplitSnapshot] = []

        tracker.splitPublisher.sink { split in
            receivedSplits.append(split)
        }.store(in: &cancellables)

        // Cross 2 mile boundaries in one update (distance jump)
        tracker.updateDistance(
            totalDistanceMeters: 3300,
            totalDurationSeconds: 960,
            elevationGainMeters: 50,
            elevationLossMeters: 30,
            currentCadence: 162,
            timeDelta: 960
        )

        XCTAssertEqual(receivedSplits.count, 2)
        XCTAssertEqual(receivedSplits[0].splitIndex, 1)
        XCTAssertEqual(receivedSplits[1].splitIndex, 2)
        XCTAssertEqual(receivedSplits[0].isPartial, false)
        XCTAssertEqual(receivedSplits[1].isPartial, false)
    }

    // MARK: - Single Split (Metric)

    func testSingleSplitMetric() {
        let tracker = SplitTracker(unitSystem: .metric, startDate: startDate)
        var receivedSplits: [SplitSnapshot] = []

        tracker.splitPublisher.sink { split in
            receivedSplits.append(split)
        }.store(in: &cancellables)

        tracker.updateDistance(
            totalDistanceMeters: 500,
            totalDurationSeconds: 150,
            elevationGainMeters: 5,
            elevationLossMeters: 2,
            currentCadence: 170,
            timeDelta: 150
        )
        XCTAssertEqual(receivedSplits.count, 0)

        // Cross 1km
        tracker.updateDistance(
            totalDistanceMeters: 1001,
            totalDurationSeconds: 300,
            elevationGainMeters: 15,
            elevationLossMeters: 8,
            currentCadence: 168,
            timeDelta: 150
        )

        XCTAssertEqual(receivedSplits.count, 1)
        XCTAssertEqual(receivedSplits[0].splitIndex, 1)
        XCTAssertEqual(receivedSplits[0].distanceMeters, 1000.0, accuracy: 0.01)
    }

    // MARK: - Partial Final Split

    func testPartialFinalSplit() {
        let tracker = SplitTracker(unitSystem: .metric, startDate: startDate)
        var receivedSplits: [SplitSnapshot] = []

        tracker.splitPublisher.sink { split in
            receivedSplits.append(split)
        }.store(in: &cancellables)

        // Cross 1km
        tracker.updateDistance(
            totalDistanceMeters: 1050,
            totalDurationSeconds: 300,
            elevationGainMeters: 10,
            elevationLossMeters: 5,
            currentCadence: 160,
            timeDelta: 300
        )
        XCTAssertEqual(receivedSplits.count, 1)

        // Now add more distance but don't reach 2km
        tracker.updateDistance(
            totalDistanceMeters: 1400,
            totalDurationSeconds: 420,
            elevationGainMeters: 18,
            elevationLossMeters: 9,
            currentCadence: 162,
            timeDelta: 120
        )

        // Generate final partial split
        let partial = tracker.finalSplit(
            totalDistanceMeters: 1400,
            totalDurationSeconds: 420,
            elevationGainMeters: 18,
            elevationLossMeters: 9
        )

        XCTAssertNotNil(partial)
        XCTAssertEqual(partial!.splitIndex, 2)
        XCTAssertEqual(partial!.distanceMeters, 400, accuracy: 1.0)
        XCTAssertTrue(partial!.isPartial)
    }

    // MARK: - No Partial When Exactly on Boundary

    func testNoPartialWhenExactlyOnBoundary() {
        let tracker = SplitTracker(unitSystem: .metric, startDate: startDate)

        tracker.splitPublisher.sink { _ in }.store(in: &cancellables)

        tracker.updateDistance(
            totalDistanceMeters: 1000,
            totalDurationSeconds: 300,
            elevationGainMeters: 0,
            elevationLossMeters: 0,
            currentCadence: nil,
            timeDelta: 300
        )

        let partial = tracker.finalSplit(
            totalDistanceMeters: 1000,
            totalDurationSeconds: 300,
            elevationGainMeters: 0,
            elevationLossMeters: 0
        )
        XCTAssertNil(partial)
    }

    // MARK: - Unit System Switching

    func testUnitSystemSwitching() {
        let tracker = SplitTracker(unitSystem: .metric, startDate: startDate)
        var receivedSplits: [SplitSnapshot] = []

        tracker.splitPublisher.sink { split in
            receivedSplits.append(split)
        }.store(in: &cancellables)

        // Run 1km in metric
        tracker.updateDistance(
            totalDistanceMeters: 1050,
            totalDurationSeconds: 300,
            elevationGainMeters: 0,
            elevationLossMeters: 0,
            currentCadence: nil,
            timeDelta: 300
        )
        XCTAssertEqual(receivedSplits.count, 1)
        XCTAssertEqual(receivedSplits[0].distanceMeters, 1000.0, accuracy: 0.01)

        // Switch to imperial — next boundary should be at 1000 + 1609.344
        tracker.changeUnitSystem(.imperial)

        // Run to 2660m (should cross 1000 + 1609.344 = 2609.344)
        tracker.updateDistance(
            totalDistanceMeters: 2660,
            totalDurationSeconds: 780,
            elevationGainMeters: 0,
            elevationLossMeters: 0,
            currentCadence: nil,
            timeDelta: 480
        )

        XCTAssertEqual(receivedSplits.count, 2)
        XCTAssertEqual(receivedSplits[1].splitIndex, 2)
        XCTAssertEqual(receivedSplits[1].distanceMeters, 1609.344, accuracy: 0.01)
    }

    // MARK: - Elevation Delta Tracking

    func testElevationDeltaPerSplit() {
        let tracker = SplitTracker(unitSystem: .metric, startDate: startDate)
        var receivedSplits: [SplitSnapshot] = []

        tracker.splitPublisher.sink { split in
            receivedSplits.append(split)
        }.store(in: &cancellables)

        // First km with 20m gain, 5m loss
        tracker.updateDistance(
            totalDistanceMeters: 1001,
            totalDurationSeconds: 300,
            elevationGainMeters: 20,
            elevationLossMeters: 5,
            currentCadence: nil,
            timeDelta: 300
        )

        // Second km with 35m total gain, 15m total loss
        tracker.updateDistance(
            totalDistanceMeters: 2001,
            totalDurationSeconds: 620,
            elevationGainMeters: 35,
            elevationLossMeters: 15,
            currentCadence: nil,
            timeDelta: 320
        )

        XCTAssertEqual(receivedSplits.count, 2)
        // First split: gain 20, loss 5
        XCTAssertEqual(receivedSplits[0].elevationGainMeters, 20, accuracy: 0.1)
        XCTAssertEqual(receivedSplits[0].elevationLossMeters, 5, accuracy: 0.1)
        // Second split: gain 15, loss 10
        XCTAssertEqual(receivedSplits[1].elevationGainMeters, 15, accuracy: 0.1)
        XCTAssertEqual(receivedSplits[1].elevationLossMeters, 10, accuracy: 0.1)
    }

    // MARK: - Cadence Averaging

    func testCadenceAveraging() {
        let tracker = SplitTracker(unitSystem: .metric, startDate: startDate)
        var receivedSplits: [SplitSnapshot] = []

        tracker.splitPublisher.sink { split in
            receivedSplits.append(split)
        }.store(in: &cancellables)

        // First update: cadence 160 for 200s
        tracker.updateDistance(
            totalDistanceMeters: 600,
            totalDurationSeconds: 200,
            elevationGainMeters: 0,
            elevationLossMeters: 0,
            currentCadence: 160,
            timeDelta: 200
        )

        // Second update: cadence 180 for 100s, cross 1km
        tracker.updateDistance(
            totalDistanceMeters: 1001,
            totalDurationSeconds: 300,
            elevationGainMeters: 0,
            elevationLossMeters: 0,
            currentCadence: 180,
            timeDelta: 100
        )

        XCTAssertEqual(receivedSplits.count, 1)
        // Weighted average: (160*200 + 180*100) / 300 = 50000/300 = 166.67
        XCTAssertNotNil(receivedSplits[0].averageCadence)
        XCTAssertEqual(receivedSplits[0].averageCadence!, 166.67, accuracy: 0.1)
    }

    // MARK: - Quarter Mile Splits

    func testQuarterMileSplits() {
        let tracker = SplitTracker(unitSystem: .imperial, splitDistance: .quarter, startDate: startDate)
        var receivedSplits: [SplitSnapshot] = []

        tracker.splitPublisher.sink { split in
            receivedSplits.append(split)
        }.store(in: &cancellables)

        // Cross 1/4 mile (402.336m)
        tracker.updateDistance(
            totalDistanceMeters: 410,
            totalDurationSeconds: 120,
            elevationGainMeters: 0,
            elevationLossMeters: 0,
            currentCadence: nil,
            timeDelta: 120
        )

        XCTAssertEqual(receivedSplits.count, 1)
        XCTAssertEqual(receivedSplits[0].splitIndex, 1)
        XCTAssertEqual(receivedSplits[0].distanceMeters, 402.336, accuracy: 0.01)
    }

    // MARK: - Half Km Splits

    func testHalfKmSplits() {
        let tracker = SplitTracker(unitSystem: .metric, splitDistance: .half, startDate: startDate)
        var receivedSplits: [SplitSnapshot] = []

        tracker.splitPublisher.sink { split in
            receivedSplits.append(split)
        }.store(in: &cancellables)

        // Cross 500m
        tracker.updateDistance(
            totalDistanceMeters: 510,
            totalDurationSeconds: 150,
            elevationGainMeters: 0,
            elevationLossMeters: 0,
            currentCadence: nil,
            timeDelta: 150
        )

        XCTAssertEqual(receivedSplits.count, 1)
        XCTAssertEqual(receivedSplits[0].distanceMeters, 500.0, accuracy: 0.01)

        // Cross 1000m (second half-km split)
        tracker.updateDistance(
            totalDistanceMeters: 1010,
            totalDurationSeconds: 300,
            elevationGainMeters: 0,
            elevationLossMeters: 0,
            currentCadence: nil,
            timeDelta: 150
        )

        XCTAssertEqual(receivedSplits.count, 2)
        XCTAssertEqual(receivedSplits[1].splitIndex, 2)
        XCTAssertEqual(receivedSplits[1].distanceMeters, 500.0, accuracy: 0.01)
    }

    // MARK: - Multiple Quarter Mile Splits in One Update

    func testMultipleQuarterMileSplitsInOneUpdate() {
        let tracker = SplitTracker(unitSystem: .imperial, splitDistance: .quarter, startDate: startDate)
        var receivedSplits: [SplitSnapshot] = []

        tracker.splitPublisher.sink { split in
            receivedSplits.append(split)
        }.store(in: &cancellables)

        // Jump past 3 quarter-mile boundaries (3 * 402.336 = 1207.008)
        tracker.updateDistance(
            totalDistanceMeters: 1250,
            totalDurationSeconds: 360,
            elevationGainMeters: 0,
            elevationLossMeters: 0,
            currentCadence: nil,
            timeDelta: 360
        )

        XCTAssertEqual(receivedSplits.count, 3)
        XCTAssertEqual(receivedSplits[0].splitIndex, 1)
        XCTAssertEqual(receivedSplits[1].splitIndex, 2)
        XCTAssertEqual(receivedSplits[2].splitIndex, 3)
    }

    // MARK: - No Cadence Data

    func testNilCadence() {
        let tracker = SplitTracker(unitSystem: .metric, startDate: startDate)
        var receivedSplits: [SplitSnapshot] = []

        tracker.splitPublisher.sink { split in
            receivedSplits.append(split)
        }.store(in: &cancellables)

        tracker.updateDistance(
            totalDistanceMeters: 1001,
            totalDurationSeconds: 300,
            elevationGainMeters: 0,
            elevationLossMeters: 0,
            currentCadence: nil,
            timeDelta: 300
        )

        XCTAssertEqual(receivedSplits.count, 1)
        XCTAssertNil(receivedSplits[0].averageCadence)
    }
}
