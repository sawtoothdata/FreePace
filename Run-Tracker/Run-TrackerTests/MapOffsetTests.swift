//
//  MapOffsetTests.swift
//  Run-TrackerTests
//

import XCTest
import CoreLocation
@testable import Run_Tracker

final class MapOffsetTests: XCTestCase {

    func testOffsetFormula_standardScreen() {
        let user = CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0)
        let result = idleCameraOffsetCenter(
            userCoordinate: user,
            latitudeDelta: 0.005,
            screenHeight: 852,  // iPhone 16 screen height in points
            overlayPanelHeight: 220
        )

        // degreesPerPoint = 0.005 / 852
        // latitudeOffset = 852 * 0.25 * degreesPerPoint = 0.005 * 0.50 = 0.00125
        let expectedOffset = 0.005 * 0.50
        XCTAssertEqual(result.latitude, 40.0 - expectedOffset, accuracy: 1e-9)
        XCTAssertEqual(result.longitude, -74.0, accuracy: 1e-9)
    }

    func testOffsetFormula_smallScreen() {
        let user = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let result = idleCameraOffsetCenter(
            userCoordinate: user,
            latitudeDelta: 0.005,
            screenHeight: 667,  // iPhone SE screen height
            overlayPanelHeight: 200
        )

        let expectedOffset = 0.005 * 0.50
        XCTAssertEqual(result.latitude, 37.7749 - expectedOffset, accuracy: 1e-9)
        XCTAssertEqual(result.longitude, -122.4194, accuracy: 1e-9)
    }

    func testOffsetFormula_largeScreen() {
        let user = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let result = idleCameraOffsetCenter(
            userCoordinate: user,
            latitudeDelta: 0.005,
            screenHeight: 956,  // iPhone 16 Pro Max
            overlayPanelHeight: 260
        )

        let expectedOffset = 0.005 * 0.50
        XCTAssertEqual(result.latitude, 51.5074 - expectedOffset, accuracy: 1e-9)
        XCTAssertEqual(result.longitude, -0.1278, accuracy: 1e-9)
    }

    func testOffsetFormula_zeroScreenHeight_returnsOriginal() {
        let user = CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0)
        let result = idleCameraOffsetCenter(
            userCoordinate: user,
            latitudeDelta: 0.005,
            screenHeight: 0,
            overlayPanelHeight: 220
        )

        XCTAssertEqual(result.latitude, 40.0, accuracy: 1e-9)
        XCTAssertEqual(result.longitude, -74.0, accuracy: 1e-9)
    }

    func testOffsetFormula_zeroOverlayHeight_stillOffsets() {
        let user = CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0)
        let result = idleCameraOffsetCenter(
            userCoordinate: user,
            latitudeDelta: 0.005,
            screenHeight: 852,
            overlayPanelHeight: 0
        )

        // Offset now depends on screenHeight, not overlayPanelHeight
        let expectedOffset = 0.005 * 0.50
        XCTAssertEqual(result.latitude, 40.0 - expectedOffset, accuracy: 1e-9)
        XCTAssertEqual(result.longitude, -74.0, accuracy: 1e-9)
    }
}
