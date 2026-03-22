//
//  ElevationFilterTests.swift
//  Run-TrackerTests
//

import XCTest
@testable import Run_Tracker

final class ElevationFilterTests: XCTestCase {

    func testBufferNotFullReturnsNil() {
        var filter = ElevationFilter(windowSize: 5)
        for i in 1...4 {
            XCTAssertNil(filter.addAltitude(Double(i)))
        }
        XCTAssertFalse(filter.isBufferFull)
    }

    func testBufferFullReturnsSmoothedValue() {
        var filter = ElevationFilter(windowSize: 5)
        // Feed 5 identical values — smoothed should equal the value
        for _ in 1...4 {
            filter.addAltitude(100.0)
        }
        let smoothed = filter.addAltitude(100.0)
        XCTAssertNotNil(smoothed)
        XCTAssertEqual(smoothed!, 100.0, accuracy: 0.001)
    }

    func testMovingAverageCalculation() {
        var filter = ElevationFilter(windowSize: 3, deadZone: 0.5)
        filter.addAltitude(10.0) // nil
        filter.addAltitude(12.0) // nil
        let s1 = filter.addAltitude(14.0) // avg(10,12,14) = 12.0
        XCTAssertEqual(s1!, 12.0, accuracy: 0.001)

        let s2 = filter.addAltitude(16.0) // avg(12,14,16) = 14.0
        XCTAssertEqual(s2!, 14.0, accuracy: 0.001)
    }

    func testElevationGainAccumulation() {
        var filter = ElevationFilter(windowSize: 3, deadZone: 0.5)
        // Steadily climbing: 0, 3, 6, 9, 12
        filter.addAltitude(0)
        filter.addAltitude(3)
        filter.addAltitude(6)  // smoothed = 3.0 (first, no delta)
        filter.addAltitude(9)  // smoothed = 6.0 (delta = +3.0 > 0.5 → gain)
        filter.addAltitude(12) // smoothed = 9.0 (delta = +3.0 > 0.5 → gain)

        XCTAssertEqual(filter.elevationGain, 6.0, accuracy: 0.001)
        XCTAssertEqual(filter.elevationLoss, 0.0, accuracy: 0.001)
    }

    func testElevationLossAccumulation() {
        var filter = ElevationFilter(windowSize: 3, deadZone: 0.5)
        // Steadily descending: 12, 9, 6, 3, 0
        filter.addAltitude(12)
        filter.addAltitude(9)
        filter.addAltitude(6)  // smoothed = 9.0 (first)
        filter.addAltitude(3)  // smoothed = 6.0 (delta = -3.0 → loss)
        filter.addAltitude(0)  // smoothed = 3.0 (delta = -3.0 → loss)

        XCTAssertEqual(filter.elevationLoss, 6.0, accuracy: 0.001)
        XCTAssertEqual(filter.elevationGain, 0.0, accuracy: 0.001)
    }

    func testDeadZoneFiltersSmallChanges() {
        var filter = ElevationFilter(windowSize: 3, deadZone: 0.5)
        // Small oscillations within dead zone
        filter.addAltitude(100.0)
        filter.addAltitude(100.1)
        filter.addAltitude(100.2)  // smoothed = 100.1
        filter.addAltitude(100.3)  // smoothed = 100.2, delta = +0.1 (within dead zone)
        filter.addAltitude(100.1)  // smoothed = 100.2, delta = 0.0 (within dead zone)

        XCTAssertEqual(filter.elevationGain, 0.0, accuracy: 0.001)
        XCTAssertEqual(filter.elevationLoss, 0.0, accuracy: 0.001)
    }

    func testMixedGainAndLoss() {
        var filter = ElevationFilter(windowSize: 3, deadZone: 0.5)
        // Up then down
        filter.addAltitude(0)
        filter.addAltitude(5)
        filter.addAltitude(10)  // smoothed = 5.0
        filter.addAltitude(15)  // smoothed = 10.0 (gain +5)
        filter.addAltitude(10)  // smoothed = 11.667 (gain +1.667)
        filter.addAltitude(5)   // smoothed = 10.0 (loss 1.667)
        filter.addAltitude(0)   // smoothed = 5.0 (loss 5.0)

        XCTAssertGreaterThan(filter.elevationGain, 0)
        XCTAssertGreaterThan(filter.elevationLoss, 0)
    }

    func testResetClearsState() {
        var filter = ElevationFilter(windowSize: 3, deadZone: 0.5)
        filter.addAltitude(0)
        filter.addAltitude(5)
        filter.addAltitude(10)
        filter.addAltitude(15)

        filter.reset()

        XCTAssertEqual(filter.elevationGain, 0)
        XCTAssertEqual(filter.elevationLoss, 0)
        XCTAssertFalse(filter.isBufferFull)
        XCTAssertNil(filter.addAltitude(100))
    }

    func testDefaultWindowSizeIsFive() {
        var filter = ElevationFilter()
        for _ in 1...4 {
            XCTAssertNil(filter.addAltitude(100))
        }
        XCTAssertNotNil(filter.addAltitude(100))
    }
}
