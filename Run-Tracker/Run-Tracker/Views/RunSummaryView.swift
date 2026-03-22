//
//  RunSummaryView.swift
//  Run-Tracker
//

import SwiftUI
import MapKit
import CoreLocation

struct RunSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    @AppStorage("timeMarkerInterval") private var timeMarkerInterval: Int = 5
    @State private var viewModel: RunSummaryVM
    @State private var showDeleteConfirmation = false
    @State private var showRouteAssignment = false
    @State private var gpxFileURL: URL?
    @State private var showWalkingSplits: Bool = true
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var summaryMapColorMode: MapColorMode = .elevation

    private let run: Run

    init(run: Run) {
        self.run = run
        self._viewModel = State(initialValue: RunSummaryVM(run: run, unitSystem: .default))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                saveRouteButton
                statCardsSection
                if viewModel.hasWeatherData {
                    weatherSection
                }
                routeMapSection
                elevationSection
                splitsSection
                if !viewModel.checkpointRows.isEmpty {
                    checkpointsSection
                }
            }
            .padding()
        }
        .navigationTitle("Run Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let url = gpxFileURL {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                } else if !run.routePoints.isEmpty {
                    Button {
                        gpxFileURL = GPXExportService.export(run: run)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .alert("Delete Run", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteRun()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this run? This cannot be undone.")
        }
        .sheet(isPresented: $showRouteAssignment) {
            RouteAssignmentSheet(
                run: run,
                freeRunCheckpoints: run.checkpointResults
                    .compactMap(\.checkpoint)
                    .filter { $0.namedRoute == nil }
            ) {
                viewModel = RunSummaryVM(run: run, unitSystem: unitSystem)
            }
        }
        .onChange(of: unitSystem) { _, newUnit in
            viewModel = RunSummaryVM(run: run, unitSystem: newUnit)
        }
        .onAppear {
            viewModel = RunSummaryVM(run: run, unitSystem: unitSystem)
            if !run.routePoints.isEmpty {
                gpxFileURL = GPXExportService.export(run: run)
                let coordinates = run.routePoints
                    .sorted { $0.distanceFromStart < $1.distanceFromStart }
                    .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                mapPosition = mapCameraPosition(for: coordinates)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text(viewModel.formattedDate)
                .font(.headline)

            Text(viewModel.timeOfDayLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let routeName = viewModel.routeName {
                Text(routeName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.blue.opacity(0.15)))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stat Cards

    private var statCardsSection: some View {
        VStack(spacing: 12) {
            if run.hasCoolDown {
                // Running section
                Text("Running")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    summaryStatCard(
                        value: viewModel.runningOnlyDistanceMeters.asDistance(unit: unitSystem),
                        label: "Distance"
                    )
                    summaryStatCard(
                        value: viewModel.runningOnlyDurationSeconds.asDuration(),
                        label: "Duration"
                    )
                    summaryStatCard(
                        value: viewModel.runningOnlyAveragePaceSecondsPerMeter.asPace(unit: unitSystem),
                        label: "Avg Pace"
                    )
                    summaryStatCard(
                        value: "\u{2191} " + viewModel.runningOnlyElevationGainMeters.asElevation(unit: unitSystem),
                        label: "Gain"
                    )
                    summaryStatCard(
                        value: "\u{2193} " + viewModel.runningOnlyElevationLossMeters.asElevation(unit: unitSystem),
                        label: "Loss"
                    )
                    if let ttfw = viewModel.timeToFirstWalk {
                        summaryStatCard(value: ttfw, label: "Time to Walk")
                    }
                }

                // Walking section
                Text("Walking")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    summaryStatCard(
                        value: viewModel.coolDownDistanceMeters.asDistance(unit: unitSystem),
                        label: "Distance"
                    )
                    summaryStatCard(
                        value: viewModel.coolDownDurationSeconds.asDuration(),
                        label: "Duration"
                    )
                }

                // Total section
                Text("Total")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    summaryStatCard(value: viewModel.formattedDistance, label: "Distance")
                    summaryStatCard(value: viewModel.formattedDuration, label: "Duration")
                }
            } else {
                // Original single-section layout
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    summaryStatCard(value: viewModel.formattedDistance, label: "Distance")
                    summaryStatCard(value: viewModel.formattedDuration, label: "Duration")
                    summaryStatCard(value: viewModel.formattedAvgPace, label: "Avg Pace")
                    summaryStatCard(value: viewModel.formattedAvgCadence, label: "Avg Cadence")
                }
            }

            // Elevation gain/loss row
            HStack(spacing: 12) {
                summaryStatCard(value: "\u{2191} " + viewModel.formattedElevationGain, label: "Gain")
                summaryStatCard(value: "\u{2193} " + viewModel.formattedElevationLoss, label: "Loss")
                summaryStatCard(value: viewModel.formattedTotalSteps, label: "Steps")
            }
        }
    }

    private func summaryStatCard(value: String, label: String) -> some View {
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

    // MARK: - Weather

    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 2) {
                    Image(systemName: "apple.logo")
                    Text("Weather")
                }                
                .font(.headline)

            HStack(spacing: 16) {
                // Condition icon + name
                if let symbol = viewModel.weatherConditionSymbol {
                    VStack(spacing: 4) {
                        Image(systemName: symbol)
                            .font(.system(size: 28))
                            .foregroundStyle(.blue)
                        if let name = viewModel.weatherConditionName {
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(minWidth: 60)
                }

                // Temperature + feels like
                if let temp = viewModel.formattedTemperature {
                    VStack(spacing: 2) {
                        Text(temp)
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        if let feels = viewModel.formattedFeelsLike {
                            Text("Feels \(feels)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Humidity
                if let humidity = viewModel.formattedHumidity {
                    VStack(spacing: 2) {
                        Text(humidity)
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        Text("Humidity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Wind
                if let wind = viewModel.formattedWind {
                    VStack(spacing: 2) {
                        Text(wind)
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        Text("Wind")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
                    Text("Data Sources")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
    }

    // MARK: - Route Map

    private var routeMapSection: some View {
        Group {
            if viewModel.elevationProfilePoints.isEmpty {
                ContentUnavailableView("No Route Data", systemImage: "map",
                                       description: Text("No route data available."))
                    .frame(height: 250)
            } else {
                let coordinates = run.routePoints
                    .sorted { $0.distanceFromStart < $1.distanceFromStart }
                    .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

                Map(position: $mapPosition) {
                    // Colored polyline segments (elevation or pace)
                    let displaySegments: [ElevationRouteSegment] = {
                        if summaryMapColorMode == .pace {
                            return summaryPaceSegments().segments
                        } else {
                            return summaryElevationSegments()
                        }
                    }()
                    if !displaySegments.isEmpty {
                        ForEach(displaySegments) { segment in
                            MapPolyline(coordinates: segment.coordinates)
                                .stroke(segment.color, lineWidth: 4)
                        }
                    } else if coordinates.count >= 2 {
                        MapPolyline(coordinates: coordinates)
                            .stroke(.blue, lineWidth: 4)
                    }

                    // Start pin (green)
                    if let first = coordinates.first {
                        Annotation("Start", coordinate: first) {
                            Image(systemName: "flag.fill")
                                .foregroundStyle(.green)
                                .font(.title3)
                        }
                    }

                    // Finish pin (red)
                    if let last = coordinates.last, coordinates.count > 1 {
                        Annotation("Finish", coordinate: last) {
                            Image(systemName: "flag.checkered")
                                .foregroundStyle(.red)
                                .font(.title3)
                        }
                    }

                    // Time markers
                    ForEach(summaryTimeMarkers()) { marker in
                        Annotation("", coordinate: marker.coordinate) {
                            VStack(spacing: 1) {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(Color(.darkGray), lineWidth: 1.5))
                                Text(marker.formattedTime)
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }

                    // Checkpoint pins
                    ForEach(summaryCheckpoints, id: \.checkpoint.id) { item in
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: item.checkpoint.latitude, longitude: item.checkpoint.longitude)) {
                            VStack(spacing: 2) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.orange)
                                Text("\(item.checkpoint.order + 1)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomLeading) {
                    Button {
                        summaryMapColorMode = summaryMapColorMode == .elevation ? .pace : .elevation
                    } label: {
                        Image(systemName: summaryMapColorMode == .pace ? "speedometer" : "mountain.2")
                            .font(.system(size: 14))
                            .frame(width: 30, height: 30)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(8)
                }
            }
        }
    }

    private func mapCameraPosition(for coordinates: [CLLocationCoordinate2D]) -> MapCameraPosition {
        guard !coordinates.isEmpty else {
            return .automatic
        }

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
        let spanLat = max((maxLat - minLat) * 1.3, 0.002) // 20% padding, min 200m span
        let spanLon = max((maxLon - minLon) * 1.3, 0.002)

        return .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        ))
    }

    // MARK: - Elevation Profile

    private var elevationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Elevation Profile")
                .font(.headline)

            ElevationProfileChart(
                dataPoints: viewModel.elevationProfilePoints,
                unitSystem: unitSystem,
                totalDistanceMeters: run.distanceMeters
            )
        }
    }

    // MARK: - Splits Table

    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Splits")
                .font(.headline)

            if run.hasCoolDown {
                Picker("Filter", selection: $showWalkingSplits) {
                    Text("All").tag(true)
                    Text("Running Only").tag(false)
                }
                .pickerStyle(.segmented)
            }

            let filteredSplits = showWalkingSplits
                ? viewModel.splitData
                : viewModel.splitData.filter { !$0.isCoolDown }
            let fullFiltered = filteredSplits.filter { !$0.isPartial }
            let fastestIdx = fullFiltered.count >= 2
                ? fullFiltered.min(by: { $0.paceSecondsPerMeter < $1.paceSecondsPerMeter })?.index
                : nil
            let slowestIdx = fullFiltered.count >= 2
                ? fullFiltered.max(by: { $0.paceSecondsPerMeter < $1.paceSecondsPerMeter })?.index
                : nil

            SplitTableView(
                splits: filteredSplits,
                fastestSplitIndex: fastestIdx,
                slowestSplitIndex: slowestIdx,
                unitSystem: unitSystem
            )
            .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
        }
    }

    // MARK: - Checkpoints

    private var checkpointsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CHECKPOINTS")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            if run.totalLaps > 1 {
                let rowsByLap = viewModel.checkpointRowsByLap
                let sortedLaps = rowsByLap.keys.sorted()
                ForEach(sortedLaps, id: \.self) { lap in
                    Text("Lap \(lap + 1)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.top, lap > 0 ? 4 : 0)
                    ForEach(rowsByLap[lap] ?? []) { row in
                        checkpointRowView(row: row)
                    }
                }
            } else {
                ForEach(viewModel.checkpointRows) { row in
                    checkpointRowView(row: row)
                }
            }
        }
    }

    private func checkpointRowView(row: CheckpointRow) -> some View {
        HStack(spacing: 0) {
            // Orange accent bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(.orange)
                .frame(width: 3)
                .padding(.vertical, 4)

            HStack {
                // Checkpoint icon + label
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin")
                            .foregroundStyle(.orange)
                            .font(.system(size: 14))
                        Text(row.label)
                            .font(.headline)
                    }

                    Text(row.elapsedSeconds.asDuration())
                        .font(.system(.title2, design: .monospaced))
                }

                Spacer()

                // Delta badge
                if let delta = row.delta {
                    checkpointDeltaBadge(delta: delta)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(.regularMaterial))
    }

    private func checkpointDeltaBadge(delta: Double) -> some View {
        let isAhead = delta <= 0
        let absDelta = abs(delta)
        let minutes = Int(absDelta) / 60
        let seconds = Int(absDelta) % 60
        let sign = isAhead ? "-" : "+"
        let text = String(format: "%@%d:%02d", sign, minutes, seconds)

        return Text(text)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(isAhead ? .green : .red))
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var saveRouteButton: some View {
        if run.namedRoute == nil {
            Button {
                showRouteAssignment = true
            } label: {
                Label("Save Route", systemImage: "tag")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Summary Map Helpers

    private func summaryTimeMarkers() -> [TimeMarker] {
        let sortedPoints = run.routePoints.sorted { $0.timestamp < $1.timestamp }
        guard let firstTimestamp = sortedPoints.first?.timestamp else { return [] }
        let intervalSeconds = Double(timeMarkerInterval * 60)
        var markers: [TimeMarker] = []
        var nextMarkerTime = intervalSeconds

        for point in sortedPoints {
            let elapsed = point.timestamp.timeIntervalSince(firstTimestamp)
            if elapsed >= nextMarkerTime {
                let minutes = Int(nextMarkerTime) / 60
                let formattedTime: String
                if minutes >= 60 {
                    formattedTime = String(format: "%d:%02d:00", minutes / 60, minutes % 60)
                } else {
                    formattedTime = String(format: "%d:00", minutes)
                }
                markers.append(TimeMarker(
                    coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                    elapsedSeconds: nextMarkerTime,
                    formattedTime: formattedTime
                ))
                nextMarkerTime += intervalSeconds
            }
        }
        return markers
    }

    private func summaryElevationSegments() -> [ElevationRouteSegment] {
        let sortedPoints = run.routePoints
            .sorted { $0.distanceFromStart < $1.distanceFromStart }
        let points: [(coordinate: CLLocationCoordinate2D, smoothedAltitude: Double)] = sortedPoints.map {
            (coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
             smoothedAltitude: $0.smoothedAltitude)
        }
        return ElevationColor.buildSegments(from: points)
    }

    private func summaryPaceSegments() -> (segments: [ElevationRouteSegment], paceRange: (min: Double, max: Double)) {
        let sortedPoints = run.routePoints
            .sorted { $0.distanceFromStart < $1.distanceFromStart }
        let points: [(coordinate: CLLocationCoordinate2D, location: CLLocation)] = sortedPoints.map {
            let coord = CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            let loc = CLLocation(
                coordinate: coord,
                altitude: $0.altitude,
                horizontalAccuracy: $0.horizontalAccuracy,
                verticalAccuracy: 0,
                timestamp: $0.timestamp
            )
            return (coordinate: coord, location: loc)
        }
        return PaceColor.buildSegments(from: points)
    }

    private var summaryCheckpoints: [(checkpoint: RouteCheckpoint, result: RunCheckpointResult)] {
        run.checkpointResults
            .compactMap { result in
                guard let cp = result.checkpoint else { return nil }
                return (checkpoint: cp, result: result)
            }
            .sorted { $0.checkpoint.order < $1.checkpoint.order }
    }

    // MARK: - Actions

    private func deleteRun() {
        let service = RunPersistenceService(modelContext: modelContext)
        service.deleteRun(run)
        dismiss()
    }
}
