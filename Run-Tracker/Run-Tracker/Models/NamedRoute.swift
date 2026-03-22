//
//  NamedRoute.swift
//  Run-Tracker
//
//  Created by Jeremy McMinis on 3/8/26.
//

import Foundation
import SwiftData

@Model
final class NamedRoute {
    var id: UUID
    var name: String
    var createdDate: Date

    @Relationship(deleteRule: .nullify, inverse: \Run.namedRoute)
    var runs: [Run]

    @Relationship(deleteRule: .cascade, inverse: \RouteCheckpoint.namedRoute)
    var checkpoints: [RouteCheckpoint] = []

    /// The run used as the benchmark for pace comparisons (nil = use best time)
    var benchmarkRunID: UUID?

    /// Whether this route is a loop (start and end are close together, checkpoints repeat each lap)
    var isLoopRoute: Bool = false

    /// Cumulative distance (meters) at which the first loop ends. When set, route polyline display
    /// is trimmed to only points within this distance, removing overlapping multi-lap data.
    var singleLapMaxDistance: Double?

    init(
        id: UUID = UUID(),
        name: String,
        createdDate: Date = Date(),
        runs: [Run] = [],
        benchmarkRunID: UUID? = nil,
        isLoopRoute: Bool = false,
        singleLapMaxDistance: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.runs = runs
        self.benchmarkRunID = benchmarkRunID
        self.isLoopRoute = isLoopRoute
        self.singleLapMaxDistance = singleLapMaxDistance
    }
}
