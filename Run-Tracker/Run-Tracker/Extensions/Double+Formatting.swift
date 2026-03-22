//
//  Double+Formatting.swift
//  Run-Tracker
//
//  Created by Jeremy McMinis on 3/8/26.
//

import Foundation

extension Double {
    /// Convert meters to display distance string (e.g., "5.23 mi" or "8.42 km")
    func asDistance(unit: UnitSystem) -> String {
        let converted = self / unit.metersPerDistanceUnit
        return String(format: "%.2f %@", converted, unit.distanceUnit)
    }

    /// Convert meters to a raw distance value in the user's unit
    func toDistanceValue(unit: UnitSystem) -> Double {
        self / unit.metersPerDistanceUnit
    }

    /// Convert seconds-per-meter to pace string (e.g., "7'48\" /mi")
    /// Input: pace in seconds per meter. If 0 or negative, returns "— —"
    func asPace(unit: UnitSystem) -> String {
        guard self > 0, self.isFinite else { return "— —" }

        let secondsPerUnit = self * unit.metersPerDistanceUnit
        guard secondsPerUnit < 3600 else { return "— —" } // cap at 60 min/unit

        let totalSeconds = Int(secondsPerUnit.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d'%02d\" %@", minutes, seconds, unit.paceUnit)
    }

    /// Convert meters to elevation display string (e.g., "342 ft" or "104 m")
    func asElevation(unit: UnitSystem) -> String {
        let converted = self / unit.metersPerElevationUnit
        return String(format: "%.0f %@", converted, unit.elevationUnit)
    }

    /// Convert meters to elevation value in user's unit
    func toElevationValue(unit: UnitSystem) -> Double {
        self / unit.metersPerElevationUnit
    }
}
