//
//  GPXExportService.swift
//  Run-Tracker
//

import Foundation

struct GPXExportService {

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let filenameDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Generates a GPX 1.1 XML string from a Run and its route points.
    static func generateGPX(from run: Run) -> String {
        let sortedPoints = run.routePoints.sorted { $0.timestamp < $1.timestamp }
        let runDateString = isoFormatter.string(from: run.startDate)
        let nameDateFormatter = DateFormatter()
        nameDateFormatter.dateStyle = .medium
        let runName = "Run on \(nameDateFormatter.string(from: run.startDate))"

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Run Tracker"
             xmlns="http://www.topografix.com/GPX/1/1">
          <metadata>
            <name>\(escapeXML(runName))</name>
            <time>\(runDateString)</time>
          </metadata>
          <trk>
            <name>Run</name>
        """

        // Split points into segments at resume points
        let segments = splitIntoSegments(sortedPoints)

        for segment in segments {
            xml += "\n    <trkseg>"
            for point in segment {
                let timeStr = isoFormatter.string(from: point.timestamp)
                xml += """

                  <trkpt lat="\(point.latitude)" lon="\(point.longitude)">
                    <ele>\(String(format: "%.1f", point.altitude))</ele>
                    <time>\(timeStr)</time>
                  </trkpt>
                """
            }
            xml += "\n    </trkseg>"
        }

        xml += "\n  </trk>\n</gpx>\n"
        return xml
    }

    /// Writes the GPX file to a temporary directory and returns the URL.
    static func export(run: Run) -> URL? {
        let gpxString = generateGPX(from: run)
        let filename = "RunTracker_\(filenameDateFormatter.string(from: run.startDate)).gpx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try gpxString.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    /// Splits route points into segments, breaking at resume points.
    private static func splitIntoSegments(_ points: [RoutePoint]) -> [[RoutePoint]] {
        guard !points.isEmpty else { return [] }

        var segments: [[RoutePoint]] = []
        var currentSegment: [RoutePoint] = []

        for point in points {
            if point.isResumePoint && !currentSegment.isEmpty {
                segments.append(currentSegment)
                currentSegment = []
            }
            currentSegment.append(point)
        }

        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }

        return segments
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
