//
//  MotionManager.swift
//  Run-Tracker
//

import Foundation
import CoreMotion
import Combine

protocol MotionProviding: AnyObject {
    func startCadenceUpdates(from startDate: Date)
    func stopCadenceUpdates()

    var currentCadence: Double? { get }
    var totalSteps: Int { get }

    var cadencePublisher: AnyPublisher<Double?, Never> { get }
    var stepsPublisher: AnyPublisher<Int, Never> { get }
}

final class MotionManager: MotionProviding {
    private let pedometer = CMPedometer()

    private let cadenceSubject = CurrentValueSubject<Double?, Never>(nil)
    private let stepsSubject = CurrentValueSubject<Int, Never>(0)

    var currentCadence: Double? { cadenceSubject.value }
    var totalSteps: Int { stepsSubject.value }

    var cadencePublisher: AnyPublisher<Double?, Never> {
        cadenceSubject.eraseToAnyPublisher()
    }

    var stepsPublisher: AnyPublisher<Int, Never> {
        stepsSubject.eraseToAnyPublisher()
    }

    static var isAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    /// Triggers the Motion & Fitness permission prompt without starting real updates.
    func requestAuthorization() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        // A short historical query is enough to trigger the system permission dialog.
        let now = Date()
        pedometer.queryPedometerData(from: now.addingTimeInterval(-1), to: now) { _, _ in }
    }

    func startCadenceUpdates(from startDate: Date) {
        guard CMPedometer.isStepCountingAvailable() else { return }

        pedometer.startUpdates(from: startDate) { [weak self] data, error in
            guard let self, let data, error == nil else { return }

            DispatchQueue.main.async {
                if let cadence = data.currentCadence {
                    // currentCadence is in steps/second, convert to steps/minute
                    self.cadenceSubject.send(cadence.doubleValue * 60.0)
                } else {
                    self.cadenceSubject.send(nil)
                }

                self.stepsSubject.send(data.numberOfSteps.intValue)
            }
        }
    }

    func stopCadenceUpdates() {
        pedometer.stopUpdates()
        cadenceSubject.send(nil)
    }
}
