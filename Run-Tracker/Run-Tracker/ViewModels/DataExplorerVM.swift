//
//  DataExplorerVM.swift
//  Run-Tracker
//

import Foundation
import SwiftData

// MARK: - Axis Enum

enum DataExplorerAxis: String, CaseIterable, Identifiable {
    case runDate = "Date"
    case distance = "Distance"
    case pace = "Pace"
    case duration = "Duration"
    case elevationGain = "Elev. Gain"
    case elevationLoss = "Elev. Loss"
    case temperature = "Temp"
    case feelsLike = "Feels Like"
    case humidity = "Humidity"
    case windSpeed = "Wind"
    case cadence = "Cadence"
    case steps = "Steps"

    var id: String { rawValue }

    var isDate: Bool { self == .runDate }

    var isWeather: Bool {
        switch self {
        case .temperature, .feelsLike, .humidity, .windSpeed: return true
        default: return false
        }
    }

    func axisLabel(unitSystem: UnitSystem) -> String {
        switch self {
        case .runDate: return "Date"
        case .distance: return unitSystem.distanceUnit
        case .pace: return "min\(unitSystem.paceUnit)"
        case .duration: return "min"
        case .elevationGain, .elevationLoss: return unitSystem.elevationUnit
        case .temperature, .feelsLike:
            return unitSystem == .imperial ? "°F" : "°C"
        case .humidity: return "%"
        case .windSpeed: return unitSystem == .imperial ? "mph" : "km/h"
        case .cadence: return "spm"
        case .steps: return "steps"
        }
    }

    func value(from run: Run, unitSystem: UnitSystem) -> Double? {
        switch self {
        case .runDate:
            return run.startDate.timeIntervalSince1970
        case .distance:
            return run.distanceMeters.toDistanceValue(unit: unitSystem)
        case .pace:
            guard run.distanceMeters > 0 else { return nil }
            let secPerMeter = run.durationSeconds / run.distanceMeters
            let secPerUnit = secPerMeter * unitSystem.metersPerDistanceUnit
            return secPerUnit / 60.0
        case .duration:
            return run.durationSeconds / 60.0
        case .elevationGain:
            return run.elevationGainMeters.toElevationValue(unit: unitSystem)
        case .elevationLoss:
            return run.elevationLossMeters.toElevationValue(unit: unitSystem)
        case .temperature:
            return run.temperatureCelsius.map {
                unitSystem == .imperial ? $0 * 9.0 / 5.0 + 32.0 : $0
            }
        case .feelsLike:
            return run.feelsLikeCelsius.map {
                unitSystem == .imperial ? $0 * 9.0 / 5.0 + 32.0 : $0
            }
        case .humidity:
            return run.humidityPercent.map { $0 * 100 }
        case .windSpeed:
            return run.windSpeedMPS.map {
                unitSystem == .imperial ? $0 * 2.23694 : $0 * 3.6
            }
        case .cadence:
            return run.averageCadence
        case .steps:
            return run.totalSteps > 0 ? Double(run.totalSteps) : nil
        }
    }
}

// MARK: - Trend Line

enum TrendLineType: String, CaseIterable {
    case none = "None"
    case linear = "Linear"
    case quadratic = "Quadratic"
}

struct TrendLinePoint: Identifiable {
    let id = UUID()
    let xValue: Double
    let yValue: Double
    let date: Date
}

// MARK: - Chart Point

struct DataExplorerPoint: Identifiable {
    let id: UUID
    let xValue: Double
    let yValue: Double
    let date: Date
}

// MARK: - ViewModel

@Observable
final class DataExplorerVM {
    private let modelContext: ModelContext

    // Filters
    var startDate: Date?
    var endDate: Date?
    var selectedRouteIDs: Set<UUID> = []
    var includeFreeRuns: Bool = false

    // Axes
    var xAxis: DataExplorerAxis = .runDate
    var yAxis: DataExplorerAxis = .distance

    // Trend line
    var trendLineType: TrendLineType = .none

    // Data
    private(set) var filteredRuns: [Run] = []
    private(set) var namedRoutes: [NamedRoute] = []
    private(set) var chartPoints: [DataExplorerPoint] = []
    private(set) var trendLinePoints: [TrendLinePoint] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchNamedRoutes()
        refresh()
    }

    func refresh() {
        fetchRuns()
        computeChartPoints(unitSystem: .default)
    }

    func refresh(unitSystem: UnitSystem) {
        fetchRuns()
        computeChartPoints(unitSystem: unitSystem)
    }

    func applyRouteFilter(selectedRouteIDs: Set<UUID>, includeFreeRuns: Bool, unitSystem: UnitSystem) {
        self.selectedRouteIDs = selectedRouteIDs
        self.includeFreeRuns = includeFreeRuns
        fetchRuns()
        computeChartPoints(unitSystem: unitSystem)
    }

    // MARK: - Fetching

    private func fetchRuns() {
        let descriptor = FetchDescriptor<Run>(
            sortBy: [SortDescriptor(\Run.startDate, order: .forward)]
        )
        var runs = (try? modelContext.fetch(descriptor)) ?? []

        if let start = startDate {
            runs = runs.filter { $0.startDate >= start }
        }
        if let end = endDate {
            // Include the entire end day
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end
            runs = runs.filter { $0.startDate < endOfDay }
        }
        let hasRouteFilter = !selectedRouteIDs.isEmpty || includeFreeRuns
        if hasRouteFilter {
            runs = runs.filter { run in
                if let routeID = run.namedRoute?.id {
                    return selectedRouteIDs.contains(routeID)
                } else {
                    return includeFreeRuns
                }
            }
        }

        filteredRuns = runs
    }

    private func fetchNamedRoutes() {
        let descriptor = FetchDescriptor<NamedRoute>(
            sortBy: [SortDescriptor(\NamedRoute.name)]
        )
        namedRoutes = (try? modelContext.fetch(descriptor)) ?? []
    }

    func computeChartPoints(unitSystem: UnitSystem) {
        chartPoints = filteredRuns.compactMap { run in
            guard let x = xAxis.value(from: run, unitSystem: unitSystem),
                  let y = yAxis.value(from: run, unitSystem: unitSystem) else {
                return nil
            }
            return DataExplorerPoint(
                id: run.id,
                xValue: x,
                yValue: y,
                date: run.startDate
            )
        }
        computeTrendLine()
    }

    func computeTrendLine() {
        guard trendLineType != .none, chartPoints.count >= 2 else {
            trendLinePoints = []
            return
        }

        let rawXs = chartPoints.map(\.xValue)
        let ys = chartPoints.map(\.yValue)
        let n = Double(rawXs.count)

        let xMin = rawXs.min()!
        let xMax = rawXs.max()!
        guard xMax > xMin else { trendLinePoints = []; return }

        // Center x values to avoid numerical overflow (critical for date timestamps)
        let xMean = rawXs.reduce(0, +) / n
        let xs = rawXs.map { $0 - xMean }

        // Generate evaluation points (centered)
        let steps = 50
        let evalXsRaw = (0...steps).map { xMin + (xMax - xMin) * Double($0) / Double(steps) }
        let evalXs = evalXsRaw.map { $0 - xMean }

        let predicted: [Double]

        switch trendLineType {
        case .none:
            trendLinePoints = []
            return

        case .linear:
            let sumX = xs.reduce(0, +)
            let sumY = ys.reduce(0, +)
            let sumXY = zip(xs, ys).map(*).reduce(0, +)
            let sumX2 = xs.map { $0 * $0 }.reduce(0, +)
            let denom = n * sumX2 - sumX * sumX
            guard denom != 0 else { trendLinePoints = []; return }
            let m = (n * sumXY - sumX * sumY) / denom
            let b = (sumY - m * sumX) / n
            predicted = evalXs.map { m * $0 + b }

        case .quadratic:
            let sumX = xs.reduce(0, +)
            let sumX2 = xs.map { $0 * $0 }.reduce(0, +)
            let sumX3 = xs.map { $0 * $0 * $0 }.reduce(0, +)
            let sumX4 = xs.map { pow($0, 4) }.reduce(0, +)
            let sumY = ys.reduce(0, +)
            let sumXY = zip(xs, ys).map(*).reduce(0, +)
            let sumX2Y = zip(xs, ys).map { $0 * $0 * $1 }.reduce(0, +)

            // Solve 3x3 system using Cramer's rule
            let det = n * (sumX2 * sumX4 - sumX3 * sumX3)
                    - sumX * (sumX * sumX4 - sumX3 * sumX2)
                    + sumX2 * (sumX * sumX3 - sumX2 * sumX2)
            guard abs(det) > 1e-15 else { trendLinePoints = []; return }

            let detC = sumY * (sumX2 * sumX4 - sumX3 * sumX3)
                     - sumX * (sumXY * sumX4 - sumX3 * sumX2Y)
                     + sumX2 * (sumXY * sumX3 - sumX2 * sumX2Y)
            let detB = n * (sumXY * sumX4 - sumX3 * sumX2Y)
                     - sumY * (sumX * sumX4 - sumX3 * sumX2)
                     + sumX2 * (sumX * sumX2Y - sumXY * sumX2)
            let detA = n * (sumX2 * sumX2Y - sumXY * sumX3)
                     - sumX * (sumX * sumX2Y - sumXY * sumX2)
                     + sumY * (sumX * sumX3 - sumX2 * sumX2)

            let a = detA / det
            let b = detB / det
            let c = detC / det
            predicted = evalXs.map { a * $0 * $0 + b * $0 + c }
        }

        // Map back to original (un-centered) x values
        let isDate = xAxis.isDate
        trendLinePoints = zip(evalXsRaw, predicted).map { x, y in
            TrendLinePoint(
                xValue: x,
                yValue: y,
                date: isDate ? Date(timeIntervalSince1970: x) : Date()
            )
        }
    }

    // MARK: - Export

    func exportCSV(unitSystem: UnitSystem) -> URL? {
        CSVExportService.export(runs: filteredRuns, unitSystem: unitSystem)
    }
}
