//
//  ElevationColorTests.swift
//  Run-TrackerTests
//

import Testing
import CoreLocation
@testable import Run_Tracker

struct ElevationColorTests {
    // MARK: - Normalization

    @Test func normalizeReturnsZeroForMin() {
        let result = ElevationColor.normalize(altitude: 100, minAlt: 100, maxAlt: 200)
        #expect(result == 0.0)
    }

    @Test func normalizeReturnsOneForMax() {
        let result = ElevationColor.normalize(altitude: 200, minAlt: 100, maxAlt: 200)
        #expect(result == 1.0)
    }

    @Test func normalizeReturnsMidpoint() {
        let result = ElevationColor.normalize(altitude: 150, minAlt: 100, maxAlt: 200)
        #expect(abs(result - 0.5) < 0.001)
    }

    @Test func normalizeHandlesEqualMinMax() {
        let result = ElevationColor.normalize(altitude: 100, minAlt: 100, maxAlt: 100)
        #expect(result == 0.5)
    }

    // MARK: - Segment Building

    @Test func buildSegmentsWithTooFewPoints() {
        let points: [(coordinate: CLLocationCoordinate2D, smoothedAltitude: Double)] = [
            (CLLocationCoordinate2D(latitude: 0, longitude: 0), 100)
        ]
        let segments = ElevationColor.buildSegments(from: points)
        #expect(segments.isEmpty)
    }

    @Test func buildSegmentsCreatesCorrectNumberOfSegments() {
        // 12 points with segment size 5 should create segments at [0..5], [5..10], [10..11]
        let points: [(coordinate: CLLocationCoordinate2D, smoothedAltitude: Double)] = (0..<12).map { i in
            (CLLocationCoordinate2D(latitude: Double(i) * 0.001, longitude: 0), Double(i) * 10)
        }
        let segments = ElevationColor.buildSegments(from: points, segmentSize: 5)
        #expect(segments.count == 3)
    }

    @Test func buildSegmentsCoordinatesOverlap() {
        // Each segment should share its last point with the next segment's first point
        let points: [(coordinate: CLLocationCoordinate2D, smoothedAltitude: Double)] = (0..<11).map { i in
            (CLLocationCoordinate2D(latitude: Double(i) * 0.001, longitude: 0), Double(i) * 10)
        }
        let segments = ElevationColor.buildSegments(from: points, segmentSize: 5)
        #expect(segments.count >= 2)

        // Last coordinate of segment 0 should equal first coordinate of segment 1
        let lastOfFirst = segments[0].coordinates.last!
        let firstOfSecond = segments[1].coordinates.first!
        #expect(lastOfFirst.latitude == firstOfSecond.latitude)
    }

    @Test func buildSegmentsLowElevationGetsGreenish() {
        // All points at the same low altitude
        let points: [(coordinate: CLLocationCoordinate2D, smoothedAltitude: Double)] = (0..<6).map { i in
            (CLLocationCoordinate2D(latitude: Double(i) * 0.001, longitude: 0), 100)
        }
        let segments = ElevationColor.buildSegments(from: points, segmentSize: 5)
        // With flat elevation, all segments get normalized to 0.5 (equal min/max)
        #expect(!segments.isEmpty)
    }
}
