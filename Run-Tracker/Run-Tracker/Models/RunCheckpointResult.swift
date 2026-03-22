//
//  RunCheckpointResult.swift
//  Run-Tracker
//

import Foundation
import SwiftData

@Model
final class RunCheckpointResult {
    var id: UUID
    var elapsedSeconds: Double
    var cumulativeDistanceMeters: Double
    var lapNumber: Int = 0

    var checkpoint: RouteCheckpoint?
    var run: Run?

    init(
        id: UUID = UUID(),
        elapsedSeconds: Double = 0,
        cumulativeDistanceMeters: Double = 0,
        lapNumber: Int = 0,
        checkpoint: RouteCheckpoint? = nil,
        run: Run? = nil
    ) {
        self.id = id
        self.elapsedSeconds = elapsedSeconds
        self.cumulativeDistanceMeters = cumulativeDistanceMeters
        self.lapNumber = lapNumber
        self.checkpoint = checkpoint
        self.run = run
    }
}
