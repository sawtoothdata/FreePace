//
//  BearingUtilsTests.swift
//  Run-TrackerTests
//

import XCTest
import CoreLocation
@testable import Run_Tracker

final class BearingUtilsTests: XCTestCase {

    // MARK: - Bearing Computation

    func testBearingNorth() {
        let bearing = BearingUtils.bearing(
            from: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            to: CLLocationCoordinate2D(latitude: 1, longitude: 0)
        )
        XCTAssertEqual(bearing, 0, accuracy: 0.1, "Due north should be ~0°")
    }

    func testBearingEast() {
        let bearing = BearingUtils.bearing(
            from: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            to: CLLocationCoordinate2D(latitude: 0, longitude: 1)
        )
        XCTAssertEqual(bearing, 90, accuracy: 0.1, "Due east should be ~90°")
    }

    func testBearingSouth() {
        let bearing = BearingUtils.bearing(
            from: CLLocationCoordinate2D(latitude: 1, longitude: 0),
            to: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        XCTAssertEqual(bearing, 180, accuracy: 0.1, "Due south should be ~180°")
    }

    func testBearingWest() {
        let bearing = BearingUtils.bearing(
            from: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            to: CLLocationCoordinate2D(latitude: 0, longitude: -1)
        )
        XCTAssertEqual(bearing, 270, accuracy: 0.1, "Due west should be ~270°")
    }

    // MARK: - Bearing Difference

    func testBearingDifferenceSameAngle() {
        XCTAssertEqual(BearingUtils.bearingDifference(90, 90), 0, accuracy: 0.001)
    }

    func testBearingDifferenceSimple() {
        XCTAssertEqual(BearingUtils.bearingDifference(0, 90), 90, accuracy: 0.001)
    }

    func testBearingDifferenceAcross360() {
        XCTAssertEqual(BearingUtils.bearingDifference(10, 350), 20, accuracy: 0.001,
                       "10° and 350° are 20° apart, not 340°")
    }

    func testBearingDifferenceOpposite() {
        XCTAssertEqual(BearingUtils.bearingDifference(0, 180), 180, accuracy: 0.001)
    }

    // MARK: - Bearing Within Tolerance

    func testWithinTolerance() {
        XCTAssertTrue(BearingUtils.isBearingWithinTolerance(actual: 30, expected: 0, tolerance: 60))
    }

    func testOutsideTolerance() {
        XCTAssertFalse(BearingUtils.isBearingWithinTolerance(actual: 180, expected: 0, tolerance: 60))
    }

    func testExactlyAtTolerance() {
        XCTAssertTrue(BearingUtils.isBearingWithinTolerance(actual: 60, expected: 0, tolerance: 60))
    }

    func testToleranceAcross360() {
        XCTAssertTrue(BearingUtils.isBearingWithinTolerance(actual: 350, expected: 10, tolerance: 30),
                      "350° is 20° from 10°, within 30° tolerance")
    }

    // MARK: - Trail Proximity Radius

    func testTrailProximityRadiusValue() {
        XCTAssertEqual(BearingUtils.trailProximityRadius, 15.0,
                       "Trail proximity radius should be 15m (trail width + GPS jitter)")
    }

    // MARK: - Loop End Distance Detection

    /// Helper to create a RoutePoint at a given coordinate with a cumulative distance.
    private func makeRoutePoint(lat: Double, lon: Double, distance: Double) -> RoutePoint {
        RoutePoint(
            latitude: lat,
            longitude: lon,
            altitude: 0,
            smoothedAltitude: 0,
            horizontalAccuracy: 5,
            speed: 3,
            distanceFromStart: distance
        )
    }

    func testDetectLoopEndDistance() {
        // Simulate a ~555m loop: start at (0,0), move far north+east, return near start
        let points = [
            makeRoutePoint(lat: 0.0, lon: 0.0, distance: 0),
            makeRoutePoint(lat: 0.001, lon: 0.0, distance: 111),    // ~111m north (departs)
            makeRoutePoint(lat: 0.002, lon: 0.0, distance: 222),    // ~222m north
            makeRoutePoint(lat: 0.002, lon: 0.001, distance: 333),  // move east
            makeRoutePoint(lat: 0.001, lon: 0.001, distance: 444),  // move south
            makeRoutePoint(lat: 0.00005, lon: 0.00005, distance: 555) // back near start (~7m away)
        ]

        let result = BearingUtils.detectLoopEndDistance(routePoints: points)
        XCTAssertNotNil(result, "Should detect loop returning near start")
        XCTAssertEqual(result!, 555, accuracy: 0.1)
    }

    func testDetectLoopEndDistanceNoLoop() {
        // Straight line — never returns to start
        let points = [
            makeRoutePoint(lat: 0.0, lon: 0.0, distance: 0),
            makeRoutePoint(lat: 0.005, lon: 0.0, distance: 556),
            makeRoutePoint(lat: 0.010, lon: 0.0, distance: 1112),
            makeRoutePoint(lat: 0.015, lon: 0.0, distance: 1668)
        ]

        let result = BearingUtils.detectLoopEndDistance(routePoints: points)
        XCTAssertNil(result, "Straight line should not detect a loop")
    }

    func testDetectLoopEndDistanceMinDistance() {
        // Points return near start before minLoopDistance (30m default) — should be ignored
        // Then the route goes far away without returning
        let points = [
            makeRoutePoint(lat: 0.0, lon: 0.0, distance: 0),
            makeRoutePoint(lat: 0.0002, lon: 0.0, distance: 22),     // ~22m north (departs)
            makeRoutePoint(lat: 0.00003, lon: 0.00003, distance: 25), // near start, only 25m cumulative (< 30m min)
            makeRoutePoint(lat: 0.005, lon: 0.0, distance: 600)       // far away afterward
        ]

        let result = BearingUtils.detectLoopEndDistance(routePoints: points)
        XCTAssertNil(result, "Should ignore returns to start before minLoopDistance")
    }

    func testDetectLoopRequiresDeparture() {
        // All points stay within proximity of start — GPS jitter while standing still.
        // Should NOT detect a loop even though cumulative distance exceeds minLoopDistance.
        let points = [
            makeRoutePoint(lat: 0.0, lon: 0.0, distance: 0),
            makeRoutePoint(lat: 0.00005, lon: 0.0, distance: 10),
            makeRoutePoint(lat: 0.0001, lon: 0.0, distance: 20),
            makeRoutePoint(lat: 0.00005, lon: 0.00005, distance: 35),
            makeRoutePoint(lat: 0.00002, lon: 0.00002, distance: 50)
        ]

        let result = BearingUtils.detectLoopEndDistance(routePoints: points)
        XCTAssertNil(result, "Should not detect loop when runner never departs start area")
    }

    func testDetectLoopFindsClosestApproach() {
        // Runner returns to start area — the closest point to start should be selected,
        // not just the first point inside the proximity zone.
        let points = [
            makeRoutePoint(lat: 0.0, lon: 0.0, distance: 0),
            makeRoutePoint(lat: 0.001, lon: 0.0, distance: 111),       // departs (~111m)
            makeRoutePoint(lat: 0.002, lon: 0.0, distance: 222),
            makeRoutePoint(lat: 0.002, lon: 0.001, distance: 333),
            makeRoutePoint(lat: 0.0001, lon: 0.0001, distance: 440),   // enters zone (~15m)
            makeRoutePoint(lat: 0.00002, lon: 0.00002, distance: 450), // closest (~3m)
            makeRoutePoint(lat: 0.0001, lon: 0.0001, distance: 460),   // moving away (~15m)
            makeRoutePoint(lat: 0.001, lon: 0.0, distance: 570)        // leaves zone
        ]

        let result = BearingUtils.detectLoopEndDistance(routePoints: points)
        XCTAssertNotNil(result, "Should detect loop")
        XCTAssertEqual(result!, 450, accuracy: 0.1, "Should pick the closest approach point")
    }

    func testDetectLoopSmallRoute() {
        // Small loop (~80m perimeter, like a park path or small block).
        // Uses explicit lower minLoopDistance to match the route scale.
        // Start at origin, go ~25m north, ~20m east, ~25m south, return near start.
        let points = [
            makeRoutePoint(lat: 0.0, lon: 0.0, distance: 0),
            makeRoutePoint(lat: 0.00015, lon: 0.0, distance: 17),       // ~17m N
            makeRoutePoint(lat: 0.00025, lon: 0.0, distance: 28),       // ~28m N (departed)
            makeRoutePoint(lat: 0.00025, lon: 0.0002, distance: 50),    // ~22m E
            makeRoutePoint(lat: 0.0, lon: 0.0002, distance: 78),        // back south
            makeRoutePoint(lat: 0.00003, lon: 0.00003, distance: 95)    // near start (~5m)
        ]

        let result = BearingUtils.detectLoopEndDistance(routePoints: points, minLoopDistance: 30)
        XCTAssertNotNil(result, "Should detect small loop")
        XCTAssertEqual(result!, 95, accuracy: 0.1)
    }
}
