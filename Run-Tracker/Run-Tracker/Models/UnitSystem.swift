//
//  UnitSystem.swift
//  Run-Tracker
//
//  Created by Jeremy McMinis on 3/8/26.
//

import Foundation

enum UnitSystem: String, Codable, CaseIterable {
    case imperial
    case metric

    static var `default`: UnitSystem {
        let locale = Locale.current
        // US, UK, Myanmar, Liberia use imperial
        guard let regionCode = locale.region?.identifier else { return .metric }
        let imperialRegions: Set<String> = ["US", "GB", "MM", "LR"]
        return imperialRegions.contains(regionCode) ? .imperial : .metric
    }

    var distanceUnit: String {
        switch self {
        case .imperial: return "mi"
        case .metric: return "km"
        }
    }

    var paceUnit: String {
        switch self {
        case .imperial: return "/mi"
        case .metric: return "/km"
        }
    }

    var elevationUnit: String {
        switch self {
        case .imperial: return "ft"
        case .metric: return "m"
        }
    }

    /// Meters per distance unit
    var metersPerDistanceUnit: Double {
        switch self {
        case .imperial: return 1609.344
        case .metric: return 1000.0
        }
    }

    /// Meters per elevation unit
    var metersPerElevationUnit: Double {
        switch self {
        case .imperial: return 0.3048
        case .metric: return 1.0
        }
    }
}
