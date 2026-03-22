//
//  Date+Formatting.swift
//  Run-Tracker
//
//  Created by Jeremy McMinis on 3/8/26.
//

import Foundation

extension Date {
    /// Format for run history rows: "Sat, Mar 7, 2026"
    func runDateDisplay() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d, yyyy"
        return formatter.string(from: self)
    }

    /// Format for run summary header: "Sat, Mar 7, 2026 · 6:42 AM"
    func runDateTimeDisplay() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d, yyyy · h:mm a"
        return formatter.string(from: self)
    }

    /// Time of day label: "Morning", "Afternoon", "Evening", "Night"
    func timeOfDayLabel() -> String {
        let hour = Calendar.current.component(.hour, from: self)
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default: return "Night"
        }
    }
}

extension Double {
    /// Format seconds as HH:MM:SS duration string
    func asDuration() -> String {
        guard self >= 0, self.isFinite else { return "00:00:00" }
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Format seconds as compact duration: "42:17" or "1:02:17"
    func asCompactDuration() -> String {
        guard self >= 0, self.isFinite else { return "0:00" }
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
