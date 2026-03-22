//
//  RoutePoint.swift
//  Run-Tracker
//
//  Created by Jeremy McMinis on 3/8/26.
//

import Foundation
import SwiftData

@Model
final class RoutePoint {
    var id: UUID
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var smoothedAltitude: Double
    var horizontalAccuracy: Double
    var speed: Double
    var distanceFromStart: Double
    var isResumePoint: Bool

    var run: Run?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        latitude: Double,
        longitude: Double,
        altitude: Double,
        smoothedAltitude: Double,
        horizontalAccuracy: Double,
        speed: Double,
        distanceFromStart: Double,
        isResumePoint: Bool = false,
        run: Run? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.smoothedAltitude = smoothedAltitude
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
        self.distanceFromStart = distanceFromStart
        self.isResumePoint = isResumePoint
        self.run = run
    }
}
