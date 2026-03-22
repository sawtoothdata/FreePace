//
//  Split.swift
//  Run-Tracker
//
//  Created by Jeremy McMinis on 3/8/26.
//

import Foundation
import SwiftData

@Model
final class Split {
    var id: UUID
    var splitIndex: Int
    var distanceMeters: Double
    var durationSeconds: Double
    var elevationGainMeters: Double
    var elevationLossMeters: Double
    var averageCadence: Double?
    var startDate: Date
    var endDate: Date
    var isPartial: Bool
    var isCoolDown: Bool

    var run: Run?

    init(
        id: UUID = UUID(),
        splitIndex: Int,
        distanceMeters: Double,
        durationSeconds: Double,
        elevationGainMeters: Double = 0,
        elevationLossMeters: Double = 0,
        averageCadence: Double? = nil,
        startDate: Date,
        endDate: Date,
        isPartial: Bool = false,
        isCoolDown: Bool = false,
        run: Run? = nil
    ) {
        self.id = id
        self.splitIndex = splitIndex
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.elevationGainMeters = elevationGainMeters
        self.elevationLossMeters = elevationLossMeters
        self.averageCadence = averageCadence
        self.startDate = startDate
        self.endDate = endDate
        self.isPartial = isPartial
        self.isCoolDown = isCoolDown
        self.run = run
    }
}
