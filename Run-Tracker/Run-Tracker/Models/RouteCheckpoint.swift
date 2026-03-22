//
//  RouteCheckpoint.swift
//  Run-Tracker
//

import Foundation
import SwiftData

@Model
final class RouteCheckpoint {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var label: String
    var order: Int

    /// Expected approach bearing in degrees (0-360). Nil means proximity-only detection.
    var expectedApproachBearing: Double?

    var namedRoute: NamedRoute?

    init(
        id: UUID = UUID(),
        latitude: Double = 0,
        longitude: Double = 0,
        label: String = "",
        order: Int = 0,
        expectedApproachBearing: Double? = nil,
        namedRoute: NamedRoute? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.label = label
        self.order = order
        self.expectedApproachBearing = expectedApproachBearing
        self.namedRoute = namedRoute
    }
}
