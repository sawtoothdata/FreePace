//
//  PaceColor.swift
//  Run-Tracker
//

import SwiftUI
import CoreLocation

enum PaceColor {
    /// Map a normalized pace value (0–1) to a color: green (fast, low value) → yellow → red (slow, high value)
    static func color(for normalizedPace: Double) -> Color {
        let t = min(max(normalizedPace, 0), 1)

        // Green (0.0) → Yellow (0.5) → Red (1.0)
        if t < 0.5 {
            let localT = t / 0.5
            return Color(
                red: localT,
                green: 0.75 + localT * 0.05,
                blue: 0.1 * (1 - localT)
            )
        } else {
            let localT = (t - 0.5) / 0.5
            return Color(
                red: 0.9 + localT * 0.1,
                green: 0.8 - localT * 0.65,
                blue: 0.0
            )
        }
    }

    /// Normalize a pace value (seconds/meter) to 0–1 given the min and max pace range.
    /// Lower pace (faster) maps to 0 (green), higher pace (slower) maps to 1 (red).
    static func normalize(pace: Double, minPace: Double, maxPace: Double) -> Double {
        guard maxPace > minPace else { return 0.5 }
        return (pace - minPace) / (maxPace - minPace)
    }

    /// Build colored segments from route points using per-segment speed.
    /// Reuses `ElevationRouteSegment` for the polyline rendering.
    static func buildSegments(
        from points: [(coordinate: CLLocationCoordinate2D, location: CLLocation)],
        segmentSize: Int = 5
    ) -> (segments: [ElevationRouteSegment], paceRange: (min: Double, max: Double)) {
        guard points.count >= 2 else { return ([], (0, 0)) }

        // Compute per-point pace (seconds per meter) from inter-point speed
        var paces: [Double] = [0] // first point has no prior
        for i in 1..<points.count {
            let dist = points[i].location.distance(from: points[i-1].location)
            let time = points[i].location.timestamp.timeIntervalSince(points[i-1].location.timestamp)
            if dist > 0 && time > 0 {
                paces.append(time / dist) // seconds per meter
            } else {
                paces.append(paces.last ?? 0)
            }
        }

        // Filter out unreasonable paces for normalization (exclude stopped/GPS jitter)
        let validPaces = paces.filter { $0 > 0 && $0 < 1.0 } // < 1.0 s/m = slower than 16:40/km
        guard let minPace = validPaces.min(), let maxPace = validPaces.max() else {
            return ([], (0, 0))
        }

        var segments: [ElevationRouteSegment] = []
        var i = 0

        while i < points.count - 1 {
            let end = min(i + segmentSize, points.count - 1)
            let segmentSlice = Array(i...end)

            // Average pace for this segment
            let avgPace = segmentSlice.map { paces[$0] }.reduce(0, +) / Double(segmentSlice.count)
            let normalized = normalize(pace: avgPace, minPace: minPace, maxPace: maxPace)
            let segColor = color(for: normalized)

            segments.append(ElevationRouteSegment(
                coordinates: segmentSlice.map { points[$0].coordinate },
                color: segColor
            ))

            i = end
        }

        return (segments, (min: minPace, max: maxPace))
    }
}
