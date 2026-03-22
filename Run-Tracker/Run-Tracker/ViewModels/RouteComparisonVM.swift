//
//  RouteComparisonVM.swift
//  Run-Tracker
//

import Foundation
import CoreLocation

/// Data for a benchmark split marker on the map
struct BenchmarkSplitMarker: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let splitIndex: Int
    let formattedTime: String
}

@Observable
final class RouteComparisonVM {
    private(set) var benchmarkRun: Run?
    private(set) var benchmarkSplitMarkers: [BenchmarkSplitMarker] = []
    private(set) var benchmarkRouteCoordinates: [CLLocationCoordinate2D] = []

    /// Current comparison delta in seconds (negative = ahead, positive = behind)
    private(set) var paceComparisonDelta: Double?

    /// Number of current run splits matched so far
    private var matchedSplitCount: Int = 0

    /// Benchmark split durations indexed by split index (cumulative times)
    private var benchmarkCumulativeTimes: [Double] = []

    // MARK: - Coach Mode Data

    /// Cumulative split times from the most recent run on the route
    private(set) var lastRunCumulativeSplitTimes: [TimeInterval] = []

    /// Average cumulative split times across all runs on the route
    private(set) var averageCumulativeSplitTimes: [TimeInterval] = []

    func loadBenchmark(for route: NamedRoute) {
        reset()

        // Find the benchmark run: use benchmarkRunID if set, otherwise best pace
        let benchmarkRun: Run?
        if let benchmarkID = route.benchmarkRunID {
            benchmarkRun = route.runs.first { $0.id == benchmarkID && !$0.routePoints.isEmpty }
        } else {
            benchmarkRun = route.runs
                .filter { !$0.routePoints.isEmpty && !$0.splits.isEmpty }
                .sorted { ($0.averagePaceSecondsPerKm ?? .infinity) < ($1.averagePaceSecondsPerKm ?? .infinity) }
                .first
        }

        guard let benchmarkRun else { return }
        self.benchmarkRun = benchmarkRun

        // Build route coordinates from benchmark
        let sortedPoints = benchmarkRun.routePoints
            .sorted { $0.distanceFromStart < $1.distanceFromStart }
        benchmarkRouteCoordinates = sortedPoints
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

        // Build split markers and cumulative times
        let sortedSplits = benchmarkRun.splits
            .sorted { $0.splitIndex < $1.splitIndex }

        var cumulativeTime: Double = 0
        for split in sortedSplits {
            cumulativeTime += split.durationSeconds

            // Find the route point closest to the split boundary distance
            let splitBoundaryDistance = Double(split.splitIndex) * split.distanceMeters
            let closestPoint = sortedPoints
                .min { abs($0.distanceFromStart - splitBoundaryDistance) < abs($1.distanceFromStart - splitBoundaryDistance) }

            if let point = closestPoint {
                let marker = BenchmarkSplitMarker(
                    coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                    splitIndex: split.splitIndex,
                    formattedTime: split.durationSeconds.asCompactDuration()
                )
                benchmarkSplitMarkers.append(marker)
            }

            benchmarkCumulativeTimes.append(cumulativeTime)
        }
    }

    /// Update comparison when a new split is completed
    func updateComparison(currentSplitIndex: Int, currentCumulativeTime: Double) {
        guard !benchmarkCumulativeTimes.isEmpty else {
            paceComparisonDelta = nil
            return
        }

        // Match against the benchmark's split at same index
        let benchmarkIndex = currentSplitIndex - 1 // splitIndex is 1-based
        guard benchmarkIndex >= 0, benchmarkIndex < benchmarkCumulativeTimes.count else {
            paceComparisonDelta = nil
            return
        }

        let benchmarkTime = benchmarkCumulativeTimes[benchmarkIndex]
        paceComparisonDelta = currentCumulativeTime - benchmarkTime
        matchedSplitCount = currentSplitIndex
    }

    /// Load coach data (last run + average cumulative split times) for a route
    func loadCoachData(for route: NamedRoute) {
        lastRunCumulativeSplitTimes = []
        averageCumulativeSplitTimes = []

        let runsWithSplits = route.runs
            .filter { !$0.splits.isEmpty }
            .sorted { $0.startDate > $1.startDate }

        guard !runsWithSplits.isEmpty else { return }

        // Last run cumulative times
        let lastRun = runsWithSplits[0]
        lastRunCumulativeSplitTimes = cumulativeTimes(for: lastRun)

        // Average cumulative times across all runs
        let allCumulatives = runsWithSplits.map { cumulativeTimes(for: $0) }
        guard !allCumulatives.isEmpty else { return }

        // Find min split count across runs for safe averaging
        let minCount = allCumulatives.map(\.count).min() ?? 0
        guard minCount > 0 else { return }

        var avgTimes: [TimeInterval] = []
        for i in 0..<minCount {
            let sum = allCumulatives.compactMap { i < $0.count ? $0[i] : nil }.reduce(0, +)
            let count = allCumulatives.filter { i < $0.count }.count
            avgTimes.append(count > 0 ? sum / Double(count) : 0)
        }
        averageCumulativeSplitTimes = avgTimes
    }

    private func cumulativeTimes(for run: Run) -> [TimeInterval] {
        let sortedSplits = run.splits
            .filter { !$0.isPartial }
            .sorted { $0.splitIndex < $1.splitIndex }
        var cumulative: Double = 0
        return sortedSplits.map { split in
            cumulative += split.durationSeconds
            return cumulative
        }
    }

    func reset() {
        benchmarkRun = nil
        benchmarkSplitMarkers = []
        benchmarkRouteCoordinates = []
        paceComparisonDelta = nil
        matchedSplitCount = 0
        benchmarkCumulativeTimes = []
        lastRunCumulativeSplitTimes = []
        averageCumulativeSplitTimes = []
    }

    var hasBenchmark: Bool {
        benchmarkRun != nil
    }

    var hasCoachData: Bool {
        !lastRunCumulativeSplitTimes.isEmpty
    }
}
