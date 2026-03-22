//
//  BearingUtils.swift
//  Run-Tracker
//

import CoreLocation

enum BearingUtils {
    /// Great-circle initial bearing from one coordinate to another, in degrees (0-360).
    static func bearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let dLon = (end.longitude - start.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let theta = atan2(y, x)

        return (theta * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Smallest angle between two bearings (0-180).
    static func bearingDifference(_ a: Double, _ b: Double) -> Double {
        let diff = abs(a - b).truncatingRemainder(dividingBy: 360)
        return diff > 180 ? 360 - diff : diff
    }

    /// Whether the actual bearing is within tolerance degrees of the expected bearing.
    static func isBearingWithinTolerance(actual: Double, expected: Double, tolerance: Double) -> Bool {
        bearingDifference(actual, expected) <= tolerance
    }

    /// Characteristic distance that defines "same spot on the trail": trail width (~5m) + GPS
    /// horizontal accuracy (~5-10m). Used for loop detection, checkpoint proximity, etc.
    static let trailProximityRadius: Double = 15.0

    /// Detect the cumulative distance at which the first loop ends.
    ///
    /// Algorithm:
    /// 1. Walk through route points sorted by cumulative distance.
    /// 2. Wait until the runner has **departed** the start area (distance > `trailProximityRadius`).
    /// 3. After departure, find the first point that returns within `trailProximityRadius` of the
    ///    start AND whose cumulative distance exceeds `minLoopDistance`.
    /// 4. Continue scanning while inside the proximity zone to find the closest approach (the
    ///    true loop-closure point), then return that point's `distanceFromStart`.
    ///
    /// `minLoopDistance` prevents GPS jitter at the very start from producing a false loop. The
    /// default (30m) is low enough to catch small loops like a house perimeter (~50-80m) while
    /// filtering out standing-still jitter.
    static func detectLoopEndDistance(
        routePoints: [RoutePoint],
        minLoopDistance: Double = 30,
        proximityRadius: Double = trailProximityRadius
    ) -> Double? {
        let sorted = routePoints.sorted { $0.distanceFromStart < $1.distanceFromStart }
        guard let first = sorted.first else { return nil }

        let startLocation = CLLocation(latitude: first.latitude, longitude: first.longitude)

        // Phase 1: runner must leave the start area
        var hasDeparted = false
        // Track the best (closest) return point once we enter the proximity zone
        var bestPoint: RoutePoint?
        var bestDistance: Double = .greatestFiniteMagnitude

        for point in sorted {
            let dist = CLLocation(latitude: point.latitude, longitude: point.longitude)
                .distance(from: startLocation)

            if !hasDeparted {
                if dist > proximityRadius {
                    hasDeparted = true
                }
                continue
            }

            // Phase 2: after departure, look for return to start
            guard point.distanceFromStart >= minLoopDistance else { continue }

            if dist <= proximityRadius {
                // Inside the proximity zone — track the closest approach
                if dist < bestDistance {
                    bestDistance = dist
                    bestPoint = point
                }
            } else if bestPoint != nil {
                // Left the proximity zone after finding a candidate — that's the loop closure
                break
            }
        }

        return bestPoint?.distanceFromStart
    }
}
