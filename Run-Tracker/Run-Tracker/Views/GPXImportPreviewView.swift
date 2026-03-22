//
//  GPXImportPreviewView.swift
//  Run-Tracker
//

import SwiftUI
import MapKit
import CoreLocation

struct GPXImportPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial

    let preview: GPXImportPreview
    @State private var didImport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    statCardsSection
                    routeMapSection
                }
                .padding()
            }
            .navigationTitle("Import Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importRun()
                    }
                    .fontWeight(.semibold)
                    .disabled(didImport)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text(preview.startDate.runDateDisplay())
                .font(.headline)

            Text(preview.startDate.timeOfDayLabel())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stat Cards

    private var statCardsSection: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(
                    value: preview.distanceMeters.asDistance(unit: unitSystem),
                    label: "Distance"
                )
                statCard(
                    value: formatDuration(preview.durationSeconds),
                    label: "Duration"
                )
                statCard(
                    value: formattedAvgPace,
                    label: "Avg Pace"
                )
                statCard(
                    value: "\(preview.routePoints.count)",
                    label: "Points"
                )
            }

            HStack(spacing: 12) {
                statCard(
                    value: "\u{2191} " + preview.elevationGainMeters.asElevation(unit: unitSystem),
                    label: "Gain"
                )
                statCard(
                    value: "\u{2193} " + preview.elevationLossMeters.asElevation(unit: unitSystem),
                    label: "Loss"
                )
                statCard(
                    value: "\(preview.splits.count)",
                    label: "Splits"
                )
            }
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
    }

    // MARK: - Route Map

    private var routeMapSection: some View {
        Group {
            if preview.routePoints.count >= 2 {
                let coordinates = preview.routePoints.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }
                Map(initialPosition: mapCameraPosition(for: coordinates)) {
                    MapPolyline(coordinates: coordinates)
                        .stroke(.blue, lineWidth: 4)

                    if let first = coordinates.first {
                        Annotation("Start", coordinate: first) {
                            Image(systemName: "flag.fill")
                                .foregroundStyle(.green)
                                .font(.title3)
                        }
                    }
                    if let last = coordinates.last {
                        Annotation("Finish", coordinate: last) {
                            Image(systemName: "flag.checkered")
                                .foregroundStyle(.red)
                                .font(.title3)
                        }
                    }
                }
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .allowsHitTesting(false)
            }
        }
    }

    private func mapCameraPosition(for coordinates: [CLLocationCoordinate2D]) -> MapCameraPosition {
        guard !coordinates.isEmpty else { return .automatic }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = max((maxLat - minLat) * 1.3, 0.002)
        let spanLon = max((maxLon - minLon) * 1.3, 0.002)

        return .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        ))
    }

    // MARK: - Helpers

    private var formattedAvgPace: String {
        guard let pace = preview.averagePaceSecondsPerKm, pace > 0 else { return "— —" }
        let secondsPerUnit = pace * unitSystem.metersPerDistanceUnit / 1000.0
        guard secondsPerUnit < 3600 else { return "— —" }
        let totalSeconds = Int(secondsPerUnit.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d'%02d\" %@", minutes, seconds, unitSystem.paceUnit)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Import Action

    private func importRun() {
        let service = RunPersistenceService(modelContext: modelContext)

        let run = Run(
            startDate: preview.startDate,
            endDate: preview.endDate,
            distanceMeters: preview.distanceMeters,
            durationSeconds: preview.durationSeconds,
            elevationGainMeters: preview.elevationGainMeters,
            elevationLossMeters: preview.elevationLossMeters,
            averagePaceSecondsPerKm: preview.averagePaceSecondsPerKm,
            totalSteps: 0
        )

        service.saveRun(run)

        // Add route points
        var cumulativeDistance: Double = 0
        var previousLocation: CLLocation?
        let isMultiSegment = preview.segments.count > 1

        for (segIndex, segment) in preview.segments.enumerated() {
            let sorted = segment.points.sorted { $0.timestamp < $1.timestamp }
            for (ptIndex, pt) in sorted.enumerated() {
                let loc = CLLocation(latitude: pt.latitude, longitude: pt.longitude)
                if let prev = previousLocation {
                    cumulativeDistance += loc.distance(from: prev)
                }
                previousLocation = loc

                let isResume = isMultiSegment && segIndex > 0 && ptIndex == 0

                let routePoint = RoutePoint(
                    timestamp: pt.timestamp,
                    latitude: pt.latitude,
                    longitude: pt.longitude,
                    altitude: pt.elevation,
                    smoothedAltitude: pt.elevation,
                    horizontalAccuracy: 0,
                    speed: 0,
                    distanceFromStart: cumulativeDistance,
                    isResumePoint: isResume
                )
                service.addRoutePoint(routePoint, to: run)
            }
        }

        // Add splits
        for snapshot in preview.splits {
            let split = Split(
                splitIndex: snapshot.splitIndex,
                distanceMeters: snapshot.distanceMeters,
                durationSeconds: snapshot.durationSeconds,
                elevationGainMeters: snapshot.elevationGainMeters,
                elevationLossMeters: snapshot.elevationLossMeters,
                averageCadence: snapshot.averageCadence,
                startDate: snapshot.startDate,
                endDate: snapshot.endDate,
                isPartial: snapshot.isPartial
            )
            service.addSplit(split, to: run)
        }

        didImport = true
        dismiss()
    }
}
