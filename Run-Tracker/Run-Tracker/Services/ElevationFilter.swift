//
//  ElevationFilter.swift
//  Run-Tracker
//

import Foundation

struct ElevationFilter {
    private let windowSize: Int
    private let deadZone: Double

    private var buffer: [Double] = []
    private var previousSmoothed: Double?

    private(set) var elevationGain: Double = 0
    private(set) var elevationLoss: Double = 0

    var isBufferFull: Bool { buffer.count >= windowSize }

    init(windowSize: Int = 5, deadZone: Double = 0.5) {
        self.windowSize = windowSize
        self.deadZone = deadZone
    }

    /// Adds a raw altitude reading and returns the smoothed altitude.
    /// Returns nil until the buffer is full (first `windowSize` readings).
    @discardableResult
    mutating func addAltitude(_ altitude: Double) -> Double? {
        buffer.append(altitude)
        if buffer.count > windowSize {
            buffer.removeFirst()
        }

        guard isBufferFull else { return nil }

        let smoothed = buffer.reduce(0, +) / Double(buffer.count)

        if let prev = previousSmoothed {
            let delta = smoothed - prev
            if delta > deadZone {
                elevationGain += delta
            } else if delta < -deadZone {
                elevationLoss += abs(delta)
            }
        }

        previousSmoothed = smoothed
        return smoothed
    }

    mutating func reset() {
        buffer.removeAll()
        previousSmoothed = nil
        elevationGain = 0
        elevationLoss = 0
    }
}
