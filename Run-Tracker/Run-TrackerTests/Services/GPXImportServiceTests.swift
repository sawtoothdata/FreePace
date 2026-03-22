//
//  GPXImportServiceTests.swift
//  Run-TrackerTests
//

import XCTest
@testable import Run_Tracker

final class GPXImportServiceTests: XCTestCase {

    // MARK: - Valid GPX Parsing

    private let validGPX = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Run Tracker"
         xmlns="http://www.topografix.com/GPX/1/1">
      <metadata>
        <name>Test Run</name>
        <time>2024-03-07T12:00:00Z</time>
      </metadata>
      <trk>
        <name>Run</name>
        <trkseg>
          <trkpt lat="43.6500" lon="-79.3800">
            <ele>76.4</ele>
            <time>2024-03-07T12:00:00Z</time>
          </trkpt>
          <trkpt lat="43.6510" lon="-79.3810">
            <ele>78.0</ele>
            <time>2024-03-07T12:01:00Z</time>
          </trkpt>
          <trkpt lat="43.6520" lon="-79.3820">
            <ele>80.5</ele>
            <time>2024-03-07T12:02:00Z</time>
          </trkpt>
        </trkseg>
      </trk>
    </gpx>
    """

    func testParseSingleSegment() throws {
        let segments = try GPXImportService.parse(string: validGPX)
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].points.count, 3)
    }

    func testParseLatLon() throws {
        let segments = try GPXImportService.parse(string: validGPX)
        let p = segments[0].points[0]
        XCTAssertEqual(p.latitude, 43.65, accuracy: 0.0001)
        XCTAssertEqual(p.longitude, -79.38, accuracy: 0.0001)
    }

    func testParseElevation() throws {
        let segments = try GPXImportService.parse(string: validGPX)
        XCTAssertEqual(segments[0].points[0].elevation, 76.4, accuracy: 0.01)
        XCTAssertEqual(segments[0].points[2].elevation, 80.5, accuracy: 0.01)
    }

    func testParseTimestamp() throws {
        let segments = try GPXImportService.parse(string: validGPX)
        let p = segments[0].points[0]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let expected = formatter.date(from: "2024-03-07T12:00:00Z")!
        XCTAssertEqual(p.timestamp, expected)
    }

    // MARK: - Multiple Segments

    func testParseMultipleSegments() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Run Tracker"
             xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <trkseg>
              <trkpt lat="43.65" lon="-79.38">
                <ele>76.4</ele>
                <time>2024-03-07T12:00:00Z</time>
              </trkpt>
            </trkseg>
            <trkseg>
              <trkpt lat="43.66" lon="-79.39">
                <ele>80.0</ele>
                <time>2024-03-07T12:05:00Z</time>
              </trkpt>
              <trkpt lat="43.67" lon="-79.40">
                <ele>82.0</ele>
                <time>2024-03-07T12:06:00Z</time>
              </trkpt>
            </trkseg>
          </trk>
        </gpx>
        """
        let segments = try GPXImportService.parse(string: gpx)
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].points.count, 1)
        XCTAssertEqual(segments[1].points.count, 2)
    }

    // MARK: - Missing Elevation

    func testParsePointWithoutElevationDefaultsToZero() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Test"
             xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <trkseg>
              <trkpt lat="43.65" lon="-79.38">
                <time>2024-03-07T12:00:00Z</time>
              </trkpt>
            </trkseg>
          </trk>
        </gpx>
        """
        let segments = try GPXImportService.parse(string: gpx)
        XCTAssertEqual(segments[0].points[0].elevation, 0)
    }

    // MARK: - Error Cases

    func testEmptyFileThrowsNoTrackPoints() {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Test"
             xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
          </trk>
        </gpx>
        """
        XCTAssertThrowsError(try GPXImportService.parse(string: gpx)) { error in
            XCTAssertTrue(error is GPXImportError)
        }
    }

    func testMissingLatThrows() {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Test"
             xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <trkseg>
              <trkpt lon="-79.38">
                <ele>76.4</ele>
              </trkpt>
            </trkseg>
          </trk>
        </gpx>
        """
        XCTAssertThrowsError(try GPXImportService.parse(string: gpx))
    }

    func testMissingLonThrows() {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Test"
             xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <trkseg>
              <trkpt lat="43.65">
                <ele>76.4</ele>
              </trkpt>
            </trkseg>
          </trk>
        </gpx>
        """
        XCTAssertThrowsError(try GPXImportService.parse(string: gpx))
    }

    // MARK: - Fractional Seconds

    func testParseFractionalSecondsTimestamp() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Test"
             xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <trkseg>
              <trkpt lat="43.65" lon="-79.38">
                <ele>76.4</ele>
                <time>2024-03-07T12:00:00.500Z</time>
              </trkpt>
            </trkseg>
          </trk>
        </gpx>
        """
        let segments = try GPXImportService.parse(string: gpx)
        XCTAssertEqual(segments[0].points.count, 1)
        // Should parse without error
    }

    // MARK: - Stats Computation (16.2)

    func testComputeStatsDistance() throws {
        // Two points ~157m apart (approx)
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Test" xmlns="http://www.topografix.com/GPX/1/1">
          <trk><trkseg>
            <trkpt lat="43.6500" lon="-79.3800"><ele>76.0</ele><time>2024-03-07T12:00:00Z</time></trkpt>
            <trkpt lat="43.6510" lon="-79.3810"><ele>76.0</ele><time>2024-03-07T12:01:00Z</time></trkpt>
          </trkseg></trk>
        </gpx>
        """
        let segments = try GPXImportService.parse(string: gpx)
        let preview = GPXImportService.computeStats(from: segments, unitSystem: .metric)
        XCTAssertGreaterThan(preview.distanceMeters, 100)
        XCTAssertLessThan(preview.distanceMeters, 200)
    }

    func testComputeStatsDuration() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Test" xmlns="http://www.topografix.com/GPX/1/1">
          <trk><trkseg>
            <trkpt lat="43.6500" lon="-79.3800"><ele>76.0</ele><time>2024-03-07T12:00:00Z</time></trkpt>
            <trkpt lat="43.6510" lon="-79.3810"><ele>76.0</ele><time>2024-03-07T12:05:00Z</time></trkpt>
          </trkseg></trk>
        </gpx>
        """
        let segments = try GPXImportService.parse(string: gpx)
        let preview = GPXImportService.computeStats(from: segments, unitSystem: .metric)
        XCTAssertEqual(preview.durationSeconds, 300, accuracy: 0.1)
    }

    func testComputeStatsDurationExcludesPauseGaps() throws {
        // Two segments: seg1 = 60s, gap = 240s, seg2 = 60s. Total should be ~120s not 360s.
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Test" xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <trkseg>
              <trkpt lat="43.6500" lon="-79.3800"><ele>76.0</ele><time>2024-03-07T12:00:00Z</time></trkpt>
              <trkpt lat="43.6510" lon="-79.3810"><ele>76.0</ele><time>2024-03-07T12:01:00Z</time></trkpt>
            </trkseg>
            <trkseg>
              <trkpt lat="43.6520" lon="-79.3820"><ele>76.0</ele><time>2024-03-07T12:05:00Z</time></trkpt>
              <trkpt lat="43.6530" lon="-79.3830"><ele>76.0</ele><time>2024-03-07T12:06:00Z</time></trkpt>
            </trkseg>
          </trk>
        </gpx>
        """
        let segments = try GPXImportService.parse(string: gpx)
        let preview = GPXImportService.computeStats(from: segments, unitSystem: .metric)
        XCTAssertEqual(preview.durationSeconds, 120, accuracy: 0.1)
    }

    func testComputeStatsAveragePace() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Test" xmlns="http://www.topografix.com/GPX/1/1">
          <trk><trkseg>
            <trkpt lat="43.6500" lon="-79.3800"><ele>76.0</ele><time>2024-03-07T12:00:00Z</time></trkpt>
            <trkpt lat="43.6510" lon="-79.3810"><ele>76.0</ele><time>2024-03-07T12:01:00Z</time></trkpt>
          </trkseg></trk>
        </gpx>
        """
        let segments = try GPXImportService.parse(string: gpx)
        let preview = GPXImportService.computeStats(from: segments, unitSystem: .metric)
        XCTAssertNotNil(preview.averagePaceSecondsPerKm)
        XCTAssertGreaterThan(preview.averagePaceSecondsPerKm!, 0)
    }

    func testComputeStatsDates() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Test" xmlns="http://www.topografix.com/GPX/1/1">
          <trk><trkseg>
            <trkpt lat="43.6500" lon="-79.3800"><ele>76.0</ele><time>2024-03-07T12:00:00Z</time></trkpt>
            <trkpt lat="43.6510" lon="-79.3810"><ele>76.0</ele><time>2024-03-07T12:05:00Z</time></trkpt>
          </trkseg></trk>
        </gpx>
        """
        let segments = try GPXImportService.parse(string: gpx)
        let preview = GPXImportService.computeStats(from: segments, unitSystem: .metric)
        XCTAssertTrue(preview.startDate < preview.endDate)
    }

    func testComputeStatsRoutePointsFlattened() throws {
        let segments = try GPXImportService.parse(string: validGPX)
        let preview = GPXImportService.computeStats(from: segments, unitSystem: .metric)
        XCTAssertEqual(preview.routePoints.count, 3)
    }

    func testComputeStatsSplitsGenerated() throws {
        // Create a GPX with enough distance for at least one split (> 1km)
        // ~10 points spaced ~200m apart = ~2km total → should get 2 splits (1 full + 1 partial)
        var gpxPoints = ""
        let baseLat = 43.65
        let baseLon = -79.38
        for i in 0..<15 {
            let lat = baseLat + Double(i) * 0.0015
            let lon = baseLon
            let time = "2024-03-07T12:\(String(format: "%02d", i)):00Z"
            gpxPoints += "<trkpt lat=\"\(lat)\" lon=\"\(lon)\"><ele>76.0</ele><time>\(time)</time></trkpt>\n"
        }
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Test" xmlns="http://www.topografix.com/GPX/1/1">
          <trk><trkseg>
            \(gpxPoints)
          </trkseg></trk>
        </gpx>
        """
        let segments = try GPXImportService.parse(string: gpx)
        let preview = GPXImportService.computeStats(from: segments, unitSystem: .metric)
        // Should have at least 1 split (partial or full)
        XCTAssertGreaterThan(preview.splits.count, 0)
        // Last split should be partial
        XCTAssertTrue(preview.splits.last!.isPartial)
    }
}
