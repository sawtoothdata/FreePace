//
//  GPXExportServiceTests.swift
//  Run-TrackerTests
//

import XCTest
@testable import Run_Tracker

final class GPXExportServiceTests: XCTestCase {

    private func makeRoutePoint(
        lat: Double, lon: Double, alt: Double,
        timestamp: Date, isResumePoint: Bool = false
    ) -> RoutePoint {
        RoutePoint(
            timestamp: timestamp,
            latitude: lat, longitude: lon,
            altitude: alt, smoothedAltitude: alt,
            horizontalAccuracy: 5.0, speed: 3.0,
            distanceFromStart: 0, isResumePoint: isResumePoint
        )
    }

    func testGPXContainsXMLHeader() {
        let run = Run(startDate: Date(), distanceMeters: 1000, durationSeconds: 300)
        let gpx = GPXExportService.generateGPX(from: run)
        XCTAssertTrue(gpx.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
    }

    func testGPXContainsGPXElement() {
        let run = Run(startDate: Date(), distanceMeters: 1000, durationSeconds: 300)
        let gpx = GPXExportService.generateGPX(from: run)
        XCTAssertTrue(gpx.contains("<gpx version=\"1.1\""))
        XCTAssertTrue(gpx.contains("</gpx>"))
    }

    func testGPXContainsMetadata() {
        let run = Run(startDate: Date(), distanceMeters: 1000, durationSeconds: 300)
        let gpx = GPXExportService.generateGPX(from: run)
        XCTAssertTrue(gpx.contains("<metadata>"))
        XCTAssertTrue(gpx.contains("<name>Run on"))
        XCTAssertTrue(gpx.contains("</metadata>"))
    }

    func testGPXContainsTrackPoints() {
        let baseDate = Date(timeIntervalSince1970: 1709800000)
        let run = Run(startDate: baseDate, distanceMeters: 1000, durationSeconds: 300)
        let p1 = makeRoutePoint(lat: 43.65, lon: -79.38, alt: 76.4, timestamp: baseDate)
        let p2 = makeRoutePoint(lat: 43.66, lon: -79.39, alt: 80.0, timestamp: baseDate.addingTimeInterval(60))
        run.routePoints = [p1, p2]

        let gpx = GPXExportService.generateGPX(from: run)
        XCTAssertTrue(gpx.contains("<trkpt lat=\"43.65\" lon=\"-79.38\">"))
        XCTAssertTrue(gpx.contains("<ele>76.4</ele>"))
        XCTAssertTrue(gpx.contains("<trkpt lat=\"43.66\" lon=\"-79.39\">"))
        XCTAssertTrue(gpx.contains("<ele>80.0</ele>"))
    }

    func testGPXSingleSegmentWhenNoPause() {
        let baseDate = Date(timeIntervalSince1970: 1709800000)
        let run = Run(startDate: baseDate, distanceMeters: 1000, durationSeconds: 300)
        let p1 = makeRoutePoint(lat: 43.65, lon: -79.38, alt: 76.4, timestamp: baseDate)
        let p2 = makeRoutePoint(lat: 43.66, lon: -79.39, alt: 80.0, timestamp: baseDate.addingTimeInterval(60))
        run.routePoints = [p1, p2]

        let gpx = GPXExportService.generateGPX(from: run)
        let segCount = gpx.components(separatedBy: "<trkseg>").count - 1
        XCTAssertEqual(segCount, 1)
    }

    func testGPXMultipleSegmentsOnPause() {
        let baseDate = Date(timeIntervalSince1970: 1709800000)
        let run = Run(startDate: baseDate, distanceMeters: 2000, durationSeconds: 600)

        let p1 = makeRoutePoint(lat: 43.65, lon: -79.38, alt: 76.4, timestamp: baseDate)
        let p2 = makeRoutePoint(lat: 43.66, lon: -79.39, alt: 80.0, timestamp: baseDate.addingTimeInterval(60))
        // Resume point starts a new segment
        let p3 = makeRoutePoint(lat: 43.67, lon: -79.40, alt: 82.0, timestamp: baseDate.addingTimeInterval(300), isResumePoint: true)
        let p4 = makeRoutePoint(lat: 43.68, lon: -79.41, alt: 85.0, timestamp: baseDate.addingTimeInterval(360))
        run.routePoints = [p1, p2, p3, p4]

        let gpx = GPXExportService.generateGPX(from: run)
        let segCount = gpx.components(separatedBy: "<trkseg>").count - 1
        XCTAssertEqual(segCount, 2)
    }

    func testGPXEmptyRoutePoints() {
        let run = Run(startDate: Date(), distanceMeters: 0, durationSeconds: 0)
        let gpx = GPXExportService.generateGPX(from: run)
        XCTAssertTrue(gpx.contains("<trk>"))
        // No trkseg when no points
        let segCount = gpx.components(separatedBy: "<trkseg>").count - 1
        XCTAssertEqual(segCount, 0)
    }

    func testGPXPointsAreSortedByTimestamp() {
        let baseDate = Date(timeIntervalSince1970: 1709800000)
        let run = Run(startDate: baseDate, distanceMeters: 1000, durationSeconds: 300)
        // Add out of order
        let p2 = makeRoutePoint(lat: 43.66, lon: -79.39, alt: 80.0, timestamp: baseDate.addingTimeInterval(60))
        let p1 = makeRoutePoint(lat: 43.65, lon: -79.38, alt: 76.4, timestamp: baseDate)
        run.routePoints = [p2, p1]

        let gpx = GPXExportService.generateGPX(from: run)
        let firstPtRange = gpx.range(of: "lat=\"43.65\"")!
        let secondPtRange = gpx.range(of: "lat=\"43.66\"")!
        XCTAssertTrue(firstPtRange.lowerBound < secondPtRange.lowerBound)
    }

    func testExportCreatesFile() {
        let run = Run(startDate: Date(), distanceMeters: 1000, durationSeconds: 300)
        let p1 = makeRoutePoint(lat: 43.65, lon: -79.38, alt: 76.4, timestamp: Date())
        run.routePoints = [p1]

        let url = GPXExportService.export(run: run)
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.lastPathComponent.hasPrefix("RunTracker_"))
        XCTAssertTrue(url!.lastPathComponent.hasSuffix(".gpx"))

        // Clean up
        try? FileManager.default.removeItem(at: url!)
    }

    func testExportedFileContainsValidGPX() throws {
        let baseDate = Date(timeIntervalSince1970: 1709800000)
        let run = Run(startDate: baseDate, distanceMeters: 1000, durationSeconds: 300)
        let p1 = makeRoutePoint(lat: 43.65, lon: -79.38, alt: 76.4, timestamp: baseDate)
        run.routePoints = [p1]

        let url = GPXExportService.export(run: run)!
        let contents = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(contents.contains("<gpx version=\"1.1\""))
        XCTAssertTrue(contents.contains("<trkpt"))

        try FileManager.default.removeItem(at: url)
    }

    func testGPXTimestampsAreISO8601() {
        let baseDate = Date(timeIntervalSince1970: 1709800000)
        let run = Run(startDate: baseDate, distanceMeters: 1000, durationSeconds: 300)
        let p1 = makeRoutePoint(lat: 43.65, lon: -79.38, alt: 76.4, timestamp: baseDate)
        run.routePoints = [p1]

        let gpx = GPXExportService.generateGPX(from: run)
        // ISO8601 format: YYYY-MM-DDTHH:MM:SSZ
        let isoPattern = "\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z"
        let regex = try! NSRegularExpression(pattern: isoPattern)
        let matches = regex.numberOfMatches(in: gpx, range: NSRange(gpx.startIndex..., in: gpx))
        XCTAssertGreaterThanOrEqual(matches, 2) // metadata time + at least one trkpt time
    }
}
