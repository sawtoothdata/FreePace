//
//  LocationManager.swift
//  Run-Tracker
//

import Foundation
import CoreLocation
import Combine

protocol LocationProviding: AnyObject {
    func startTracking()
    func stopTracking()
    func pauseTracking()
    func resumeTracking()

    var currentLocation: CLLocation? { get }
    var authorizationStatus: CLAuthorizationStatus { get }

    var locationPublisher: AnyPublisher<CLLocation, Never> { get }
    var authorizationPublisher: AnyPublisher<CLAuthorizationStatus, Never> { get }
}

final class LocationManager: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    private let authorizationSubject = CurrentValueSubject<CLAuthorizationStatus, Never>(.notDetermined)

    private(set) var currentLocation: CLLocation?

    var authorizationStatus: CLAuthorizationStatus {
        authorizationSubject.value
    }

    var locationPublisher: AnyPublisher<CLLocation, Never> {
        locationSubject.eraseToAnyPublisher()
    }

    var authorizationPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        authorizationSubject.eraseToAnyPublisher()
    }

    private var isTracking = false

    override init() {
        super.init()
        manager.delegate = self
        authorizationSubject.send(manager.authorizationStatus)
    }

    func startTracking() {
        manager.requestWhenInUseAuthorization()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.activityType = .fitness
        manager.startUpdatingLocation()
        isTracking = true
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        isTracking = false
    }

    func pauseTracking() {
        manager.stopUpdatingLocation()
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        isTracking = false
    }

    func resumeTracking() {
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.startUpdatingLocation()
        isTracking = true
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        locationSubject.send(location)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationSubject.send(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // GPS errors are expected in some conditions (tunnels, indoors)
        // Don't stop tracking — CLLocationManager will retry automatically
    }
}
