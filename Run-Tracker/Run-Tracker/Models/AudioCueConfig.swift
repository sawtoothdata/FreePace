//
//  AudioCueConfig.swift
//  Run-Tracker
//

import Foundation

/// Fields that can be included in split-based audio cues
enum AudioCueField: String, CaseIterable, Identifiable {
    case totalDistance = "totalDistance"
    case totalTime = "totalTime"
    case splitTime = "splitTime"
    case splitPace = "splitPace"
    case averagePace = "averagePace"
    // Coach mode comparison fields (only announced when coach mode is active)
    case totalTimeVsLastRun = "totalTimeVsLastRun"
    case splitTimeVsLastRun = "splitTimeVsLastRun"
    case splitPaceVsLastRun = "splitPaceVsLastRun"
    case averagePaceVsLastRun = "averagePaceVsLastRun"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .totalDistance: return "Total Distance"
        case .totalTime: return "Total Time"
        case .splitTime: return "Split Time"
        case .splitPace: return "Split Pace"
        case .averagePace: return "Average Pace"
        case .totalTimeVsLastRun: return "Total Time vs Last Run"
        case .splitTimeVsLastRun: return "Split Time vs Last Run"
        case .splitPaceVsLastRun: return "Split Pace vs Last Run"
        case .averagePaceVsLastRun: return "Avg Pace vs Last Run"
        }
    }

    /// Whether this field is a coach-mode comparison field
    var isCoachField: Bool {
        switch self {
        case .totalTimeVsLastRun, .splitTimeVsLastRun,
             .splitPaceVsLastRun, .averagePaceVsLastRun:
            return true
        default:
            return false
        }
    }

    /// The base (non-coach) fields
    static var baseFields: [AudioCueField] {
        allCases.filter { !$0.isCoachField }
    }

    /// The coach comparison fields
    static var coachFields: [AudioCueField] {
        allCases.filter { $0.isCoachField }
    }
}

/// Helpers for reading/writing sets of enabled fields as comma-separated @AppStorage strings
enum AudioCueConfigStorage {
    static let defaultFields: String = AudioCueField.allCases.map(\.rawValue).joined(separator: ",")

    static func parseFields(_ raw: String) -> Set<AudioCueField> {
        let parts = raw.split(separator: ",").map(String.init)
        return Set(parts.compactMap { AudioCueField(rawValue: $0) })
    }

    static func serialize(_ fields: Set<AudioCueField>) -> String {
        fields.map(\.rawValue).sorted().joined(separator: ",")
    }
}
