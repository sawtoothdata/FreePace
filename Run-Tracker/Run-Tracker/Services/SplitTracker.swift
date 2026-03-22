//
//  SplitTracker.swift
//  Run-Tracker
//

import Foundation
import Combine

struct SplitSnapshot {
    let splitIndex: Int
    let distanceMeters: Double
    let durationSeconds: Double
    let elevationGainMeters: Double
    let elevationLossMeters: Double
    let averageCadence: Double?
    let startDate: Date
    let endDate: Date
    let isPartial: Bool
    var isCoolDown: Bool = false
}

final class SplitTracker {
    private(set) var unitSystem: UnitSystem
    private(set) var splitDistance: SplitDistance
    private(set) var splitDistanceMeters: Double
    private(set) var splitIndex: Int = 0
    private(set) var nextSplitBoundary: Double

    // Accumulated stats since last split
    private var splitStartDistance: Double = 0
    private var splitStartDuration: Double = 0
    private var splitStartElevationGain: Double = 0
    private var splitStartElevationLoss: Double = 0
    private var splitStartDate: Date
    private var cadenceSamples: [(cadence: Double, duration: Double)] = []

    private let splitSubject = PassthroughSubject<SplitSnapshot, Never>()
    var splitPublisher: AnyPublisher<SplitSnapshot, Never> {
        splitSubject.eraseToAnyPublisher()
    }

    init(unitSystem: UnitSystem, splitDistance: SplitDistance = .full, startDate: Date = Date()) {
        self.unitSystem = unitSystem
        self.splitDistance = splitDistance
        self.splitDistanceMeters = splitDistance.metersValue(for: unitSystem)
        self.nextSplitBoundary = self.splitDistanceMeters
        self.splitStartDate = startDate
    }

    func updateDistance(
        totalDistanceMeters: Double,
        totalDurationSeconds: Double,
        elevationGainMeters: Double,
        elevationLossMeters: Double,
        currentCadence: Double?,
        timeDelta: Double
    ) {
        // Accumulate cadence samples
        if let cadence = currentCadence, timeDelta > 0 {
            cadenceSamples.append((cadence: cadence, duration: timeDelta))
        }

        // Check if we've crossed split boundaries (could cross multiple in one update)
        while totalDistanceMeters >= nextSplitBoundary {
            splitIndex += 1

            let splitDistance = splitDistanceMeters
            let splitDuration = totalDurationSeconds - splitStartDuration
            let splitElevationGain = elevationGainMeters - splitStartElevationGain
            let splitElevationLoss = elevationLossMeters - splitStartElevationLoss
            let avgCadence = computeAverageCadence()

            let now = Date()
            let snapshot = SplitSnapshot(
                splitIndex: splitIndex,
                distanceMeters: splitDistance,
                durationSeconds: splitDuration,
                elevationGainMeters: splitElevationGain,
                elevationLossMeters: splitElevationLoss,
                averageCadence: avgCadence,
                startDate: splitStartDate,
                endDate: now,
                isPartial: false
            )

            splitSubject.send(snapshot)

            // Reset for next split
            splitStartDistance = nextSplitBoundary
            splitStartDuration = totalDurationSeconds
            splitStartElevationGain = elevationGainMeters
            splitStartElevationLoss = elevationLossMeters
            splitStartDate = now
            cadenceSamples.removeAll()
            nextSplitBoundary += splitDistanceMeters
        }
    }

    /// Generate the final partial split when the run ends
    func finalSplit(
        totalDistanceMeters: Double,
        totalDurationSeconds: Double,
        elevationGainMeters: Double,
        elevationLossMeters: Double
    ) -> SplitSnapshot? {
        let remainingDistance = totalDistanceMeters - splitStartDistance
        guard remainingDistance > 0 else { return nil }

        let splitDuration = totalDurationSeconds - splitStartDuration
        let splitElevationGain = elevationGainMeters - splitStartElevationGain
        let splitElevationLoss = elevationLossMeters - splitStartElevationLoss
        let avgCadence = computeAverageCadence()

        return SplitSnapshot(
            splitIndex: splitIndex + 1,
            distanceMeters: remainingDistance,
            durationSeconds: splitDuration,
            elevationGainMeters: splitElevationGain,
            elevationLossMeters: splitElevationLoss,
            averageCadence: avgCadence,
            startDate: splitStartDate,
            endDate: Date(),
            isPartial: true
        )
    }

    func changeUnitSystem(_ newUnit: UnitSystem) {
        unitSystem = newUnit
        splitDistanceMeters = splitDistance.metersValue(for: newUnit)
        // Recalculate boundary from current split start
        nextSplitBoundary = splitStartDistance + splitDistanceMeters
    }

    private func computeAverageCadence() -> Double? {
        guard !cadenceSamples.isEmpty else { return nil }
        let totalDuration = cadenceSamples.reduce(0.0) { $0 + $1.duration }
        guard totalDuration > 0 else { return nil }
        let weightedSum = cadenceSamples.reduce(0.0) { $0 + $1.cadence * $1.duration }
        return weightedSum / totalDuration
    }
}
