//
//  RunSummaryVM.swift
//  Run-Tracker
//

import Foundation

/// Data point for the elevation profile chart
struct ElevationProfilePoint: Identifiable {
    let id = UUID()
    let distanceMeters: Double
    let elevationMeters: Double
}

/// Display data for a single split row
struct SplitDisplayData: Identifiable {
    let id = UUID()
    let index: Int
    let distanceMeters: Double
    let cumulativeDistanceMeters: Double
    let durationSeconds: Double
    let paceSecondsPerMeter: Double
    let elevationGainMeters: Double
    let elevationLossMeters: Double
    let averageCadence: Double?
    let isPartial: Bool
    var isCoolDown: Bool = false
}

/// Display data for a checkpoint row in RunSummaryView
struct CheckpointRow: Identifiable {
    let id = UUID()
    let label: String
    let elapsedSeconds: Double
    let delta: Double? // negative = ahead, positive = behind; nil = no benchmark
    let lapNumber: Int
}

@Observable
final class RunSummaryVM {
    let run: Run

    // MARK: - Formatted Display Values

    let formattedDate: String
    let formattedDistance: String
    let formattedDuration: String
    let formattedAvgPace: String
    let formattedAvgCadence: String
    let formattedElevationGain: String
    let formattedElevationLoss: String
    let formattedTotalSteps: String
    let routeName: String?
    let timeOfDayLabel: String

    // MARK: - Weather Display
    let hasWeatherData: Bool
    let weatherConditionSymbol: String?
    let weatherConditionName: String?
    let formattedTemperature: String?
    let formattedFeelsLike: String?
    let formattedHumidity: String?
    let formattedWind: String?

    // MARK: - Raw Values for display

    let distanceValue: Double
    let durationValue: Double
    let avgPaceSecondsPerMeter: Double
    let avgCadenceValue: Double?
    let elevationGainValue: Double
    let elevationLossValue: Double
    let totalSteps: Int

    // MARK: - Computed Data

    let splitData: [SplitDisplayData]
    let elevationProfilePoints: [ElevationProfilePoint]
    let fastestSplitIndex: Int?
    let slowestSplitIndex: Int?

    // MARK: - Cool Down Stats

    var runningOnlySplits: [Split] {
        run.splits.filter { !$0.isCoolDown }
    }

    var runningOnlyDistanceMeters: Double {
        run.distanceMeters - run.coolDownDistanceMeters
    }

    var runningOnlyDurationSeconds: Double {
        run.durationSeconds - run.coolDownDurationSeconds
    }

    var runningOnlyElevationGainMeters: Double {
        runningOnlySplits.reduce(0.0) { $0 + $1.elevationGainMeters }
    }

    var runningOnlyElevationLossMeters: Double {
        runningOnlySplits.reduce(0.0) { $0 + $1.elevationLossMeters }
    }

    var runningOnlyAveragePaceSecondsPerMeter: Double {
        guard runningOnlyDistanceMeters > 0 else { return 0 }
        return runningOnlyDurationSeconds / runningOnlyDistanceMeters
    }

    var coolDownDistanceMeters: Double {
        run.coolDownDistanceMeters
    }

    var coolDownDurationSeconds: Double {
        run.coolDownDurationSeconds
    }

    var timeToFirstWalk: String? {
        guard let seconds = run.timeToFirstWalkSeconds else { return nil }
        return seconds.asDuration()
    }

    // MARK: - Checkpoint Rows

    private struct BenchmarkKey: Hashable {
        let checkpointID: UUID
        let lap: Int
    }

    var checkpointRows: [CheckpointRow] {
        let results = run.checkpointResults.sorted { $0.cumulativeDistanceMeters < $1.cumulativeDistanceMeters }
        guard !results.isEmpty else { return [] }

        // Find benchmark run's checkpoint results for delta computation (keyed by checkpoint+lap)
        var benchmarkResults: [BenchmarkKey: RunCheckpointResult] = [:]
        if let route = run.namedRoute,
           let benchmarkID = route.benchmarkRunID,
           let benchmarkRun = route.runs.first(where: { $0.id == benchmarkID && $0.id != run.id }) {
            for result in benchmarkRun.checkpointResults {
                if let cpID = result.checkpoint?.id {
                    let key = BenchmarkKey(checkpointID: cpID, lap: result.lapNumber)
                    benchmarkResults[key] = result
                }
            }
        }

        return results.compactMap { result in
            guard let checkpoint = result.checkpoint else { return nil }
            let key = BenchmarkKey(checkpointID: checkpoint.id, lap: result.lapNumber)
            let delta: Double?
            if let benchmarkResult = benchmarkResults[key] {
                delta = result.elapsedSeconds - benchmarkResult.elapsedSeconds
            } else {
                delta = nil
            }
            return CheckpointRow(
                label: checkpoint.label,
                elapsedSeconds: result.elapsedSeconds,
                delta: delta,
                lapNumber: result.lapNumber
            )
        }
    }

    /// Checkpoint rows grouped by lap number (for multi-lap display)
    var checkpointRowsByLap: [Int: [CheckpointRow]] {
        Dictionary(grouping: checkpointRows, by: \.lapNumber)
    }

    // MARK: - Init

    init(run: Run, unitSystem: UnitSystem) {
        self.run = run

        // Date
        self.formattedDate = run.startDate.runDateTimeDisplay()
        self.routeName = run.namedRoute?.name
        self.timeOfDayLabel = run.startDate.timeOfDayLabel()

        // Weather
        if run.temperatureCelsius != nil {
            self.hasWeatherData = true
            self.weatherConditionSymbol = run.weatherConditionSymbol
            self.weatherConditionName = run.weatherCondition

            let tempC = run.temperatureCelsius!
            let feelsC = run.feelsLikeCelsius ?? tempC
            switch unitSystem {
            case .imperial:
                let tempF = tempC * 9.0 / 5.0 + 32.0
                let feelsF = feelsC * 9.0 / 5.0 + 32.0
                self.formattedTemperature = String(format: "%.0f°F", tempF)
                self.formattedFeelsLike = String(format: "%.0f°F", feelsF)
            case .metric:
                self.formattedTemperature = String(format: "%.0f°C", tempC)
                self.formattedFeelsLike = String(format: "%.0f°C", feelsC)
            }

            if let humidity = run.humidityPercent {
                self.formattedHumidity = String(format: "%.0f%%", humidity * 100)
            } else {
                self.formattedHumidity = nil
            }

            if let windMPS = run.windSpeedMPS {
                switch unitSystem {
                case .imperial:
                    let mph = windMPS * 2.23694
                    self.formattedWind = String(format: "%.0f mph", mph)
                case .metric:
                    let kmh = windMPS * 3.6
                    self.formattedWind = String(format: "%.0f km/h", kmh)
                }
            } else {
                self.formattedWind = nil
            }
        } else {
            self.hasWeatherData = false
            self.weatherConditionSymbol = nil
            self.weatherConditionName = nil
            self.formattedTemperature = nil
            self.formattedFeelsLike = nil
            self.formattedHumidity = nil
            self.formattedWind = nil
        }

        // Distance
        self.distanceValue = run.distanceMeters
        self.formattedDistance = run.distanceMeters.asDistance(unit: unitSystem)

        // Duration
        self.durationValue = run.durationSeconds
        self.formattedDuration = run.durationSeconds.asDuration()

        // Average Pace
        if run.distanceMeters > 0 {
            self.avgPaceSecondsPerMeter = run.durationSeconds / run.distanceMeters
        } else {
            self.avgPaceSecondsPerMeter = 0
        }
        self.formattedAvgPace = self.avgPaceSecondsPerMeter.asPace(unit: unitSystem)

        // Average Cadence
        self.avgCadenceValue = run.averageCadence
        if let cadence = run.averageCadence {
            self.formattedAvgCadence = String(format: "%.0f spm", cadence)
        } else {
            self.formattedAvgCadence = "—"
        }

        // Elevation
        self.elevationGainValue = run.elevationGainMeters
        self.elevationLossValue = run.elevationLossMeters
        self.formattedElevationGain = run.elevationGainMeters.asElevation(unit: unitSystem)
        self.formattedElevationLoss = run.elevationLossMeters.asElevation(unit: unitSystem)

        // Steps
        self.totalSteps = run.totalSteps
        self.formattedTotalSteps = "\(run.totalSteps)"

        // Splits
        let sortedSplits = run.splits.sorted { $0.splitIndex < $1.splitIndex }
        var splitDisplays: [SplitDisplayData] = []
        var cumulativeDistance: Double = 0
        for split in sortedSplits {
            cumulativeDistance += split.distanceMeters
            let pace: Double = split.distanceMeters > 0
                ? split.durationSeconds / split.distanceMeters
                : 0
            splitDisplays.append(SplitDisplayData(
                index: split.splitIndex,
                distanceMeters: split.distanceMeters,
                cumulativeDistanceMeters: cumulativeDistance,
                durationSeconds: split.durationSeconds,
                paceSecondsPerMeter: pace,
                elevationGainMeters: split.elevationGainMeters,
                elevationLossMeters: split.elevationLossMeters,
                averageCadence: split.averageCadence,
                isPartial: split.isPartial,
                isCoolDown: split.isCoolDown
            ))
        }
        self.splitData = splitDisplays

        // Fastest/slowest split (only among full splits)
        let fullSplits = splitDisplays.filter { !$0.isPartial }
        if fullSplits.count >= 2 {
            self.fastestSplitIndex = fullSplits.min(by: { $0.paceSecondsPerMeter < $1.paceSecondsPerMeter })?.index
            self.slowestSplitIndex = fullSplits.max(by: { $0.paceSecondsPerMeter < $1.paceSecondsPerMeter })?.index
        } else {
            self.fastestSplitIndex = nil
            self.slowestSplitIndex = nil
        }

        // Elevation profile from route points
        let sortedPoints = run.routePoints.sorted { $0.distanceFromStart < $1.distanceFromStart }
        self.elevationProfilePoints = sortedPoints.map { point in
            ElevationProfilePoint(
                distanceMeters: point.distanceFromStart,
                elevationMeters: point.smoothedAltitude
            )
        }
    }
}
