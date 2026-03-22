//
//  SettingsVM.swift
//  Run-Tracker
//

import Foundation
import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum SplitDistance: String, CaseIterable {
    case quarter
    case half
    case full

    func metersValue(for unitSystem: UnitSystem) -> Double {
        switch (self, unitSystem) {
        case (.quarter, .imperial): return 402.336    // 1/4 mile
        case (.half, .imperial):    return 804.672    // 1/2 mile
        case (.full, .imperial):    return 1609.344   // 1 mile
        case (.quarter, .metric):   return 250.0      // 1/4 km
        case (.half, .metric):      return 500.0      // 1/2 km
        case (.full, .metric):      return 1000.0     // 1 km
        }
    }

    func displayName(for unitSystem: UnitSystem) -> String {
        switch (self, unitSystem) {
        case (.quarter, .imperial): return "¼ mi"
        case (.half, .imperial):    return "½ mi"
        case (.full, .imperial):    return "1 mi"
        case (.quarter, .metric):   return "¼ km"
        case (.half, .metric):      return "½ km"
        case (.full, .metric):      return "1 km"
        }
    }

    /// Label for split toast and table header (e.g. "¼ Mi", "½ Km")
    func splitLabel(for unitSystem: UnitSystem) -> String {
        switch (self, unitSystem) {
        case (.quarter, .imperial): return "¼ Mi"
        case (.half, .imperial):    return "½ Mi"
        case (.full, .imperial):    return "Mile"
        case (.quarter, .metric):   return "¼ Km"
        case (.half, .metric):      return "½ Km"
        case (.full, .metric):      return "Km"
        }
    }

    /// Spoken label for audio cues (e.g. "Quarter mile", "Half K", "Mile")
    func spokenLabel(for unitSystem: UnitSystem) -> String {
        switch (self, unitSystem) {
        case (.quarter, .imperial): return "Quarter mile"
        case (.half, .imperial):    return "Half mile"
        case (.full, .imperial):    return "Mile"
        case (.quarter, .metric):   return "Quarter K"
        case (.half, .metric):      return "Half K"
        case (.full, .metric):      return "Kilometer"
        }
    }
}

enum TimeMarkerInterval: Int, CaseIterable {
    case oneMinute = 1
    case twoMinutes = 2
    case fiveMinutes = 5
    case tenMinutes = 10

    var displayName: String {
        switch self {
        case .oneMinute: return "1 min"
        case .twoMinutes: return "2 min"
        case .fiveMinutes: return "5 min"
        case .tenMinutes: return "10 min"
        }
    }
}

enum AudioCueInterval: Int, CaseIterable {
    case oneMinute = 1
    case fiveMinutes = 5
    case tenMinutes = 10

    var displayName: String {
        switch self {
        case .oneMinute: return "1 min"
        case .fiveMinutes: return "5 min"
        case .tenMinutes: return "10 min"
        }
    }
}
