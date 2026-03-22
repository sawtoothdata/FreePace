//
//  Run_TrackerApp.swift
//  Run-Tracker
//
//  Created by Jeremy McMinis on 3/8/26.
//

import SwiftUI
import SwiftData

@main
struct Run_TrackerApp: App {
    @State private var locationManager = LocationManager()
    @State private var motionManager = MotionManager()
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("splitDistance") private var splitDistance: SplitDistance = .full
    @AppStorage("timeMarkersEnabled") private var timeMarkersEnabled: Bool = false
    @AppStorage("timeMarkerInterval") private var timeMarkerInterval: Int = 5

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Run", systemImage: "figure.run") {
                    NavigationStack {
                        ActiveRunView(
                            viewModel: ActiveRunVM(
                                locationProvider: locationManager,
                                motionProvider: motionManager,
                                unitSystem: unitSystem,
                                splitDistance: splitDistance,
                                timeMarkersEnabled: timeMarkersEnabled,
                                timeMarkerIntervalMinutes: timeMarkerInterval
                            )
                        )
                    }
                }

                Tab("Runs", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") {
                    RunHistoryListView()
                }

                Tab("Settings", systemImage: "gearshape") {
                    SettingsView()
                }
            }
            .preferredColorScheme(appearanceMode.colorScheme)
            .onAppear {
                motionManager.requestAuthorization()
            }
        }
        .modelContainer(for: [
            Run.self,
            Split.self,
            RoutePoint.self,
            NamedRoute.self,
            RouteCheckpoint.self,
            RunCheckpointResult.self,
        ])
    }
}
