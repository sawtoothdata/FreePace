//
//  ElevationColor.swift
//  Run-Tracker
//

import SwiftUI

/// A segment of the route polyline with an associated elevation-based color
struct ElevationRouteSegment: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
}

import CoreLocation

enum ElevationColor {
    /// Map a normalized elevation value (0–1) to a color on the green → yellow → orange → brown gradient.
    static func color(for normalizedElevation: Double) -> Color {
        let t = min(max(normalizedElevation, 0), 1)

        // Green (0.0) → Yellow (0.33) → Orange (0.66) → Brown (1.0)
        if t < 0.33 {
            let localT = t / 0.33
            return Color(
                red: localT * 0.8,
                green: 0.7 + localT * 0.1,
                blue: 0.2 * (1 - localT)
            )
        } else if t < 0.66 {
            let localT = (t - 0.33) / 0.33
            return Color(
                red: 0.8 + localT * 0.2,
                green: 0.8 - localT * 0.35,
                blue: 0.0
            )
        } else {
            let localT = (t - 0.66) / 0.34
            return Color(
                red: 1.0 - localT * 0.4,
                green: 0.45 - localT * 0.2,
                blue: localT * 0.1
            )
        }
    }

    /// Normalize an altitude to 0–1 given the min and max altitude range
    static func normalize(altitude: Double, minAlt: Double, maxAlt: Double) -> Double {
        guard maxAlt > minAlt else { return 0.5 }
        return (altitude - minAlt) / (maxAlt - minAlt)
    }

    /// Build colored segments from route points. Groups points into segments of ~segmentSize points.
    static func buildSegments(
        from points: [(coordinate: CLLocationCoordinate2D, smoothedAltitude: Double)],
        segmentSize: Int = 5
    ) -> [ElevationRouteSegment] {
        guard points.count >= 2 else { return [] }

        let altitudes = points.map(\.smoothedAltitude)
        let minAlt = altitudes.min() ?? 0
        let maxAlt = altitudes.max() ?? 0

        var segments: [ElevationRouteSegment] = []
        var i = 0

        while i < points.count - 1 {
            let end = min(i + segmentSize, points.count - 1)
            let segmentPoints = Array(points[i...end])

            // Average altitude for this segment
            let avgAlt = segmentPoints.map(\.smoothedAltitude).reduce(0, +) / Double(segmentPoints.count)
            let normalized = normalize(altitude: avgAlt, minAlt: minAlt, maxAlt: maxAlt)
            let segColor = color(for: normalized)

            segments.append(ElevationRouteSegment(
                coordinates: segmentPoints.map(\.coordinate),
                color: segColor
            ))

            i = end
        }

        return segments
    }
}
