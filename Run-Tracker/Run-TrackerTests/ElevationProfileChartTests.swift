//
//  ElevationProfileChartTests.swift
//  Run-TrackerTests
//

import XCTest
@testable import Run_Tracker

final class ElevationProfileChartTests: XCTestCase {

    // MARK: - Empty Points

    func testEmptyPoints() {
        let range = elevationChartDomain(points: [], unitSystem: .imperial)
        XCTAssertEqual(range.lowerBound, -5)
        XCTAssertEqual(range.upperBound, 5)
    }

    // MARK: - Flat Run (all same elevation)

    func testFlatRunImperial() {
        let points = [
            ElevationProfilePoint(distanceMeters: 0, elevationMeters: 30.48),   // 100 ft
            ElevationProfilePoint(distanceMeters: 500, elevationMeters: 30.48),
            ElevationProfilePoint(distanceMeters: 1000, elevationMeters: 30.48)
        ]
        let range = elevationChartDomain(points: points, unitSystem: .imperial)
        // 30.48m * 3.28084 = 100 ft, flat so ±5
        XCTAssertEqual(range.lowerBound, 100 - 5, accuracy: 0.1)
        XCTAssertEqual(range.upperBound, 100 + 5, accuracy: 0.1)
    }

    func testFlatRunMetric() {
        let points = [
            ElevationProfilePoint(distanceMeters: 0, elevationMeters: 50),
            ElevationProfilePoint(distanceMeters: 1000, elevationMeters: 50)
        ]
        let range = elevationChartDomain(points: points, unitSystem: .metric)
        XCTAssertEqual(range.lowerBound, 45, accuracy: 0.1)
        XCTAssertEqual(range.upperBound, 55, accuracy: 0.1)
    }

    // MARK: - Small Elevation Change (~20 ft)

    func testSmallElevationChangeImperial() {
        // 0 ft to ~20 ft = 0m to 6.096m
        let points = [
            ElevationProfilePoint(distanceMeters: 0, elevationMeters: 0),
            ElevationProfilePoint(distanceMeters: 500, elevationMeters: 3.048),
            ElevationProfilePoint(distanceMeters: 1000, elevationMeters: 6.096)
        ]
        let range = elevationChartDomain(points: points, unitSystem: .imperial)
        // min=0ft, max=20ft, padding = max(20*0.15, 1) = 3ft
        XCTAssertEqual(range.lowerBound, -3, accuracy: 0.1)
        XCTAssertEqual(range.upperBound, 23, accuracy: 0.1)
    }

    // MARK: - Large Elevation Change (~500 ft)

    func testLargeElevationChangeImperial() {
        // 0 ft to ~500 ft = 0m to 152.4m
        let points = [
            ElevationProfilePoint(distanceMeters: 0, elevationMeters: 0),
            ElevationProfilePoint(distanceMeters: 5000, elevationMeters: 152.4)
        ]
        let range = elevationChartDomain(points: points, unitSystem: .imperial)
        // min=0ft, max=500ft, padding = 500*0.15 = 75ft
        XCTAssertEqual(range.lowerBound, -75, accuracy: 0.5)
        XCTAssertEqual(range.upperBound, 575, accuracy: 0.5)
    }
}
