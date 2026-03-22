//
//  MapOffset.swift
//  Run-Tracker
//

import CoreLocation

/// Computes an offset camera center that shifts the user's coordinate south
/// so the user dot appears centered in the visible area above the overlay panel.
///
/// - Parameters:
///   - userCoordinate: The user's true GPS coordinate
///   - latitudeDelta: The map's latitude span in degrees (e.g. 0.005)
///   - screenHeight: The full screen height in points
///   - overlayPanelHeight: The height of the bottom overlay panel in points
/// - Returns: A coordinate shifted south by half the overlay panel height in degrees
func idleCameraOffsetCenter(
    userCoordinate: CLLocationCoordinate2D,
    latitudeDelta: Double,
    screenHeight: CGFloat,
    overlayPanelHeight: CGFloat
) -> CLLocationCoordinate2D {
    guard screenHeight > 0 else { return userCoordinate }
    let degreesPerPoint = latitudeDelta / Double(screenHeight)
    let latitudeOffset = Double(screenHeight) * 0.50 * degreesPerPoint
    return CLLocationCoordinate2D(
        latitude: userCoordinate.latitude - latitudeOffset,
        longitude: userCoordinate.longitude
    )
}
