//
//  UnitConversionTests.swift
//  Run-TrackerTests
//
//  Created by Jeremy McMinis on 3/8/26.
//

import Testing
@testable import Run_Tracker

struct UnitConversionTests {

    // MARK: - Distance

    @Test func distanceImperialOneMile() {
        let meters = 1609.344
        let result = meters.asDistance(unit: .imperial)
        #expect(result == "1.00 mi")
    }

    @Test func distanceMetricOneKm() {
        let meters = 1000.0
        let result = meters.asDistance(unit: .metric)
        #expect(result == "1.00 km")
    }

    @Test func distanceFiveKm() {
        let meters = 5000.0
        let result = meters.asDistance(unit: .metric)
        #expect(result == "5.00 km")
    }

    @Test func distanceImperialFiveMiles() {
        let meters = 5.0 * 1609.344
        let result = meters.asDistance(unit: .imperial)
        #expect(result == "5.00 mi")
    }

    @Test func distanceZero() {
        let result = (0.0).asDistance(unit: .imperial)
        #expect(result == "0.00 mi")
    }

    // MARK: - Pace

    @Test func paceImperial() {
        // 8 min/mi = 480 seconds per 1609.344 meters
        let secondsPerMeter = 480.0 / 1609.344
        let result = secondsPerMeter.asPace(unit: .imperial)
        #expect(result == "8'00\" /mi")
    }

    @Test func paceMetric() {
        // 5 min/km = 300 seconds per 1000 meters
        let secondsPerMeter = 300.0 / 1000.0
        let result = secondsPerMeter.asPace(unit: .metric)
        #expect(result == "5'00\" /km")
    }

    @Test func paceWithSeconds() {
        // 7:48/mi = 468 seconds per 1609.344 meters
        let secondsPerMeter = 468.0 / 1609.344
        let result = secondsPerMeter.asPace(unit: .imperial)
        #expect(result == "7'48\" /mi")
    }

    @Test func paceZeroReturnsDash() {
        let result = (0.0).asPace(unit: .imperial)
        #expect(result == "— —")
    }

    @Test func paceNegativeReturnsDash() {
        let result = (-1.0).asPace(unit: .imperial)
        #expect(result == "— —")
    }

    @Test func paceInfiniteReturnsDash() {
        let result = Double.infinity.asPace(unit: .imperial)
        #expect(result == "— —")
    }

    // MARK: - Elevation

    @Test func elevationImperial() {
        let meters = 100.0
        let result = meters.asElevation(unit: .imperial)
        // 100m = 328.084 ft ≈ 328 ft
        #expect(result == "328 ft")
    }

    @Test func elevationMetric() {
        let meters = 100.0
        let result = meters.asElevation(unit: .metric)
        #expect(result == "100 m")
    }

    @Test func elevationZero() {
        let result = (0.0).asElevation(unit: .imperial)
        #expect(result == "0 ft")
    }

    // MARK: - Raw value conversions

    @Test func toDistanceValueImperial() {
        let meters = 1609.344
        let value = meters.toDistanceValue(unit: .imperial)
        #expect(abs(value - 1.0) < 0.001)
    }

    @Test func toElevationValueImperial() {
        let meters = 0.3048
        let value = meters.toElevationValue(unit: .imperial)
        #expect(abs(value - 1.0) < 0.001)
    }

    // MARK: - UnitSystem defaults

    @Test func unitSystemHasDistanceUnit() {
        #expect(UnitSystem.imperial.distanceUnit == "mi")
        #expect(UnitSystem.metric.distanceUnit == "km")
    }

    @Test func unitSystemHasPaceUnit() {
        #expect(UnitSystem.imperial.paceUnit == "/mi")
        #expect(UnitSystem.metric.paceUnit == "/km")
    }

    @Test func unitSystemHasElevationUnit() {
        #expect(UnitSystem.imperial.elevationUnit == "ft")
        #expect(UnitSystem.metric.elevationUnit == "m")
    }
}
