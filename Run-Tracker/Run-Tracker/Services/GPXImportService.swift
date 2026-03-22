//
//  GPXImportService.swift
//  Run-Tracker
//

import Foundation
import CoreLocation
import Combine

// MARK: - Parsed Data Types

struct ParsedTrackPoint {
    let latitude: Double
    let longitude: Double
    let elevation: Double
    let timestamp: Date
}

struct ParsedTrackSegment {
    let points: [ParsedTrackPoint]
}

enum GPXImportError: LocalizedError {
    case fileReadFailed
    case invalidXML(String)
    case noTrackPoints
    case missingRequiredAttribute(String)

    var errorDescription: String? {
        switch self {
        case .fileReadFailed:
            return "Could not read the GPX file."
        case .invalidXML(let detail):
            return "Invalid GPX file: \(detail)"
        case .noTrackPoints:
            return "The GPX file contains no track points."
        case .missingRequiredAttribute(let attr):
            return "Track point missing required attribute: \(attr)"
        }
    }
}

// MARK: - GPXImportService

struct GPXImportService {

    /// Parse a GPX 1.1 file from a URL into track segments.
    static func parse(url: URL) throws -> [ParsedTrackSegment] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            throw GPXImportError.fileReadFailed
        }
        return try parse(data: data)
    }

    /// Parse GPX 1.1 XML data into track segments.
    static func parse(data: Data) throws -> [ParsedTrackSegment] {
        let delegate = GPXParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()

        if let error = delegate.parseError {
            throw error
        }

        let segments = delegate.segments.filter { !$0.points.isEmpty }
        guard !segments.isEmpty else {
            throw GPXImportError.noTrackPoints
        }

        return segments
    }

    /// Parse GPX 1.1 XML string into track segments.
    static func parse(string: String) throws -> [ParsedTrackSegment] {
        guard let data = string.data(using: .utf8) else {
            throw GPXImportError.invalidXML("Could not encode string as UTF-8")
        }
        return try parse(data: data)
    }
}

// MARK: - Import Preview

struct GPXImportPreview: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let distanceMeters: Double
    let durationSeconds: Double
    let elevationGainMeters: Double
    let elevationLossMeters: Double
    let averagePaceSecondsPerKm: Double?
    let splits: [SplitSnapshot]
    let routePoints: [ParsedTrackPoint]
    let segments: [ParsedTrackSegment]
}

extension GPXImportService {

    /// Compute run statistics from parsed track segments.
    static func computeStats(
        from segments: [ParsedTrackSegment],
        unitSystem: UnitSystem,
        splitDistance: SplitDistance = .full
    ) -> GPXImportPreview {
        let allPoints = segments.flatMap { $0.points }.sorted { $0.timestamp < $1.timestamp }
        guard let firstPoint = allPoints.first, let lastPoint = allPoints.last else {
            return GPXImportPreview(
                startDate: Date(), endDate: Date(),
                distanceMeters: 0, durationSeconds: 0,
                elevationGainMeters: 0, elevationLossMeters: 0,
                averagePaceSecondsPerKm: nil, splits: [],
                routePoints: [], segments: segments
            )
        }

        // Compute total distance by summing distances between consecutive points
        // within each segment (don't count distance across pause gaps)
        var totalDistance: Double = 0
        for segment in segments {
            let sorted = segment.points.sorted { $0.timestamp < $1.timestamp }
            for i in 1..<sorted.count {
                let prev = CLLocation(latitude: sorted[i-1].latitude, longitude: sorted[i-1].longitude)
                let curr = CLLocation(latitude: sorted[i].latitude, longitude: sorted[i].longitude)
                totalDistance += curr.distance(from: prev)
            }
        }

        // Duration: sum of per-segment durations (excludes pause gaps)
        var totalDuration: TimeInterval = 0
        for segment in segments {
            let sorted = segment.points.sorted { $0.timestamp < $1.timestamp }
            if let first = sorted.first, let last = sorted.last {
                totalDuration += last.timestamp.timeIntervalSince(first.timestamp)
            }
        }

        // Elevation gain/loss using ElevationFilter
        var elevFilter = ElevationFilter()
        for point in allPoints {
            elevFilter.addAltitude(point.elevation)
        }

        // Splits
        let splitTracker = SplitTracker(
            unitSystem: unitSystem,
            splitDistance: splitDistance,
            startDate: firstPoint.timestamp
        )
        var cumulativeDistance: Double = 0
        var cumulativeDuration: Double = 0
        var collectedSplits: [SplitSnapshot] = []

        // Collect splits via publisher
        let cancellable = splitTracker.splitPublisher.sink { snapshot in
            collectedSplits.append(snapshot)
        }

        for segment in segments {
            let sorted = segment.points.sorted { $0.timestamp < $1.timestamp }
            for i in 1..<sorted.count {
                let prev = CLLocation(latitude: sorted[i-1].latitude, longitude: sorted[i-1].longitude)
                let curr = CLLocation(latitude: sorted[i].latitude, longitude: sorted[i].longitude)
                let dist = curr.distance(from: prev)
                let timeDelta = sorted[i].timestamp.timeIntervalSince(sorted[i-1].timestamp)

                cumulativeDistance += dist
                cumulativeDuration += timeDelta

                splitTracker.updateDistance(
                    totalDistanceMeters: cumulativeDistance,
                    totalDurationSeconds: cumulativeDuration,
                    elevationGainMeters: elevFilter.elevationGain,
                    elevationLossMeters: elevFilter.elevationLoss,
                    currentCadence: nil,
                    timeDelta: timeDelta
                )
            }
        }

        // Final partial split
        if let finalSplit = splitTracker.finalSplit(
            totalDistanceMeters: cumulativeDistance,
            totalDurationSeconds: cumulativeDuration,
            elevationGainMeters: elevFilter.elevationGain,
            elevationLossMeters: elevFilter.elevationLoss
        ) {
            collectedSplits.append(finalSplit)
        }

        cancellable.cancel()

        // Average pace (seconds per km)
        let avgPace: Double? = totalDistance > 0
            ? (totalDuration / (totalDistance / 1000.0))
            : nil

        return GPXImportPreview(
            startDate: firstPoint.timestamp,
            endDate: lastPoint.timestamp,
            distanceMeters: totalDistance,
            durationSeconds: totalDuration,
            elevationGainMeters: elevFilter.elevationGain,
            elevationLossMeters: elevFilter.elevationLoss,
            averagePaceSecondsPerKm: avgPace,
            splits: collectedSplits,
            routePoints: allPoints,
            segments: segments
        )
    }
}

// MARK: - XMLParser Delegate

private class GPXParserDelegate: NSObject, XMLParserDelegate {
    var segments: [ParsedTrackSegment] = []
    var parseError: GPXImportError?

    private var currentPoints: [ParsedTrackPoint] = []
    private var inTrkSeg = false
    private var inTrkPt = false
    private var currentElement = ""
    private var currentText = ""

    private var currentLat: Double?
    private var currentLon: Double?
    private var currentEle: Double?
    private var currentTime: Date?

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        currentElement = elementName.lowercased()

        switch currentElement {
        case "trkseg":
            inTrkSeg = true
            currentPoints = []

        case "trkpt":
            inTrkPt = true
            currentText = ""
            currentEle = nil
            currentTime = nil

            if let latStr = attributes["lat"], let lat = Double(latStr) {
                currentLat = lat
            } else {
                parseError = .missingRequiredAttribute("lat")
                parser.abortParsing()
                return
            }
            if let lonStr = attributes["lon"], let lon = Double(lonStr) {
                currentLon = lon
            } else {
                parseError = .missingRequiredAttribute("lon")
                parser.abortParsing()
                return
            }

        case "ele", "time":
            currentText = ""

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inTrkPt && (currentElement == "ele" || currentElement == "time") {
            currentText += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        let name = elementName.lowercased()

        switch name {
        case "ele":
            currentEle = Double(currentText.trimmingCharacters(in: .whitespacesAndNewlines))

        case "time":
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            currentTime = Self.isoFormatter.date(from: trimmed)
                ?? Self.isoFormatterNoFrac.date(from: trimmed)

        case "trkpt":
            if let lat = currentLat, let lon = currentLon {
                let point = ParsedTrackPoint(
                    latitude: lat,
                    longitude: lon,
                    elevation: currentEle ?? 0,
                    timestamp: currentTime ?? Date.distantPast
                )
                currentPoints.append(point)
            }
            inTrkPt = false

        case "trkseg":
            if !currentPoints.isEmpty {
                segments.append(ParsedTrackSegment(points: currentPoints))
            }
            currentPoints = []
            inTrkSeg = false

        default:
            break
        }

        currentElement = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        if self.parseError == nil {
            self.parseError = .invalidXML(parseError.localizedDescription)
        }
    }
}
