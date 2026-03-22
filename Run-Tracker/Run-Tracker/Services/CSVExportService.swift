//
//  CSVExportService.swift
//  Run-Tracker
//

import Foundation

struct CSVExportService {

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let filenameDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func generateCSV(from runs: [Run], unitSystem: UnitSystem) -> String {
        let distUnit = unitSystem.distanceUnit
        let eleUnit = unitSystem.elevationUnit
        let tempUnit = unitSystem == .imperial ? "°F" : "°C"
        let windUnit = unitSystem == .imperial ? "mph" : "km/h"
        let paceUnit = unitSystem == .imperial ? "min/mi" : "min/km"

        var lines: [String] = []

        // Header
        lines.append([
            "Date",
            "Distance (\(distUnit))",
            "Duration (min)",
            "Pace (\(paceUnit))",
            "Elevation Gain (\(eleUnit))",
            "Elevation Loss (\(eleUnit))",
            "Temperature (\(tempUnit))",
            "Feels Like (\(tempUnit))",
            "Humidity (%)",
            "Wind Speed (\(windUnit))",
            "Cadence (spm)",
            "Steps",
            "Route"
        ].joined(separator: ","))

        for run in runs {
            let date = dateFormatter.string(from: run.startDate)
            let distance = formatNum(run.distanceMeters.toDistanceValue(unit: unitSystem))
            let duration = formatNum(run.durationSeconds / 60.0)

            let paceVal: String
            if run.distanceMeters > 0 {
                let secPerMeter = run.durationSeconds / run.distanceMeters
                let secPerUnit = secPerMeter * unitSystem.metersPerDistanceUnit
                paceVal = formatNum(secPerUnit / 60.0)
            } else {
                paceVal = ""
            }

            let eleGain = formatNum(run.elevationGainMeters.toElevationValue(unit: unitSystem))
            let eleLoss = formatNum(run.elevationLossMeters.toElevationValue(unit: unitSystem))

            let temp = run.temperatureCelsius.map { formatNum(convertTemp($0, unit: unitSystem)) } ?? ""
            let feelsLike = run.feelsLikeCelsius.map { formatNum(convertTemp($0, unit: unitSystem)) } ?? ""
            let humidity = run.humidityPercent.map { formatNum($0 * 100) } ?? ""
            let wind = run.windSpeedMPS.map { formatNum(convertWind($0, unit: unitSystem)) } ?? ""
            let cadence = run.averageCadence.map { formatNum($0) } ?? ""
            let steps = run.totalSteps > 0 ? "\(run.totalSteps)" : ""
            let route = escapeCSV(run.namedRoute?.name ?? "")

            lines.append([
                date, distance, duration, paceVal,
                eleGain, eleLoss, temp, feelsLike,
                humidity, wind, cadence, steps, route
            ].joined(separator: ","))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    static func export(runs: [Run], unitSystem: UnitSystem) -> URL? {
        let csv = generateCSV(from: runs, unitSystem: unitSystem)
        let datePart = filenameDateFormatter.string(from: Date())
        let filename = "RunTracker_Export_\(datePart).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private static func formatNum(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func convertTemp(_ celsius: Double, unit: UnitSystem) -> Double {
        unit == .imperial ? celsius * 9.0 / 5.0 + 32.0 : celsius
    }

    private static func convertWind(_ mps: Double, unit: UnitSystem) -> Double {
        unit == .imperial ? mps * 2.23694 : mps * 3.6
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
