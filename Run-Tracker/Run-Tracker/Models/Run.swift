//
//  Run.swift
//  Run-Tracker
//
//  Created by Jeremy McMinis on 3/8/26.
//

import Foundation
import SwiftData

@Model
final class Run {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var distanceMeters: Double
    var durationSeconds: Double
    var elevationGainMeters: Double
    var elevationLossMeters: Double
    var averagePaceSecondsPerKm: Double?
    var averageCadence: Double?
    var totalSteps: Int

    // Weather data (captured at run start)
    var temperatureCelsius: Double?
    var feelsLikeCelsius: Double?
    var humidityPercent: Double?     // 0.0–1.0
    var windSpeedMPS: Double?        // meters per second
    var weatherCondition: String?    // "clear", "cloudy", "rain", "snow", etc.
    var weatherConditionSymbol: String? // SF Symbol name

    // Cool-down aggregate fields
    var hasCoolDown: Bool = false
    var coolDownDistanceMeters: Double = 0
    var coolDownDurationSeconds: Double = 0

    // Time to first walk segment
    var timeToFirstWalkSeconds: Double? = nil

    // Lap tracking
    var totalLaps: Int = 1

    var namedRoute: NamedRoute?

    @Relationship(deleteRule: .cascade, inverse: \Split.run)
    var splits: [Split]

    @Relationship(deleteRule: .cascade, inverse: \RoutePoint.run)
    var routePoints: [RoutePoint]

    @Relationship(deleteRule: .cascade, inverse: \RunCheckpointResult.run)
    var checkpointResults: [RunCheckpointResult] = []

    init(
        id: UUID = UUID(),
        startDate: Date = Date(),
        endDate: Date? = nil,
        distanceMeters: Double = 0,
        durationSeconds: Double = 0,
        elevationGainMeters: Double = 0,
        elevationLossMeters: Double = 0,
        averagePaceSecondsPerKm: Double? = nil,
        averageCadence: Double? = nil,
        totalSteps: Int = 0,
        temperatureCelsius: Double? = nil,
        feelsLikeCelsius: Double? = nil,
        humidityPercent: Double? = nil,
        windSpeedMPS: Double? = nil,
        weatherCondition: String? = nil,
        weatherConditionSymbol: String? = nil,
        namedRoute: NamedRoute? = nil,
        splits: [Split] = [],
        routePoints: [RoutePoint] = []
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.elevationGainMeters = elevationGainMeters
        self.elevationLossMeters = elevationLossMeters
        self.averagePaceSecondsPerKm = averagePaceSecondsPerKm
        self.averageCadence = averageCadence
        self.totalSteps = totalSteps
        self.temperatureCelsius = temperatureCelsius
        self.feelsLikeCelsius = feelsLikeCelsius
        self.humidityPercent = humidityPercent
        self.windSpeedMPS = windSpeedMPS
        self.weatherCondition = weatherCondition
        self.weatherConditionSymbol = weatherConditionSymbol
        self.namedRoute = namedRoute
        self.splits = splits
        self.routePoints = routePoints
    }
}
