//
//  RouteDetailView.swift
//  Run-Tracker
//

import SwiftUI
import SwiftData
import MapKit
import Charts

// MARK: - Route Chart Metric

enum RouteChartMetric: String, CaseIterable, Identifiable {
    case checkpointTime = "Checkpoint"
    case pace = "Pace"
    case duration = "Duration"

    var id: String { rawValue }
    var label: String { rawValue }

    var isCheckpointMetric: Bool { self == .checkpointTime }

    func yLabel(unitSystem: UnitSystem) -> String {
        switch self {
        case .checkpointTime: return "min"
        case .pace: return "min/\(unitSystem.distanceUnit)"
        case .duration: return "min"
        }
    }

    func formatYAxis(_ value: Double, unitSystem: UnitSystem) -> String {
        switch self {
        case .pace:
            let totalSeconds = Int(value * 60)
            let m = totalSeconds / 60
            let s = totalSeconds % 60
            return "\(m)'\(String(format: "%02d", s))\""
        case .checkpointTime, .duration:
            let totalSeconds = Int(value * 60)
            let m = totalSeconds / 60
            let s = totalSeconds % 60
            return "\(m):\(String(format: "%02d", s))"
        }
    }
}

enum RouteDetailTab: String, CaseIterable {
    case splits = "Splits"
    case runs = "Runs"
}

struct RouteDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    @AppStorage("splitDistance") private var splitDistance: SplitDistance = .full

    let route: NamedRoute

    @State private var showRenameAlert = false
    @State private var showDeleteConfirmation = false
    @State private var renameText = ""
    @State private var showDeleteCheckpointConfirmation = false
    @State private var checkpointToDelete: RouteCheckpoint?
    @State private var isEditingPins = false
    @State private var showCheckpointLabelAlert = false
    @State private var newCheckpointLabel = ""
    @State private var pendingCheckpointCoordinate: CLLocationCoordinate2D?

    // Chart state
    @State private var selectedChartMetric: RouteChartMetric = .checkpointTime
    @State private var selectedCheckpointID: UUID?
    @State private var chartTrendLine: TrendLineType = .none

    // Bottom tab
    @State private var selectedDetailTab: RouteDetailTab = .splits

    var body: some View {
        mainContent
            .navigationTitle(route.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if routeCoordinates != nil {
                        Button(isEditingPins ? "Done" : "Edit Pins") {
                            withAnimation { isEditingPins.toggle() }
                        }
                    }
                }
            }
            .alert("Rename Route", isPresented: $showRenameAlert) {
                TextField("Route name", text: $renameText)
                Button("Save") { renameRoute() }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Delete Route", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) { deleteRoute() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will unlink all runs from this route. The runs will not be deleted.")
            }
            .alert("Remove Checkpoint?", isPresented: $showDeleteCheckpointConfirmation) {
                Button("Remove", role: .destructive) {
                    if let checkpoint = checkpointToDelete {
                        removeCheckpoint(checkpoint)
                        checkpointToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { checkpointToDelete = nil }
            }
            .alert("Pin Label", isPresented: $showCheckpointLabelAlert) {
                TextField("Checkpoint name", text: $newCheckpointLabel)
                Button("Add") {
                    if let coord = pendingCheckpointCoordinate {
                        addCheckpoint(at: coord, label: newCheckpointLabel)
                    }
                    pendingCheckpointCoordinate = nil
                    newCheckpointLabel = ""
                }
                Button("Cancel", role: .cancel) {
                    pendingCheckpointCoordinate = nil
                    newCheckpointLabel = ""
                }
            } message: {
                Text("Enter a name for this checkpoint, or leave blank for a default.")
            }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                routeMapSection
                if isEditingPins {
                    editPinsSection
                }
                timingStatsSection
                paceTrendSection
                detailTabSection
                actionsSection
            }
            .padding()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(route.name)
                    .font(.title2.bold())
                Text("\(route.runs.count) \(route.runs.count == 1 ? "run" : "runs")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Route Map

    private var routeMapSection: some View {
        Group {
            if let coordinates = routeCoordinates, !coordinates.isEmpty {
                MapReader { proxy in
                    Map(initialPosition: mapCameraPosition(for: coordinates)) {
                        // Route polyline
                        if coordinates.count >= 2 {
                            MapPolyline(coordinates: coordinates)
                                .stroke(.green, lineWidth: 4)
                        }

                        // Start pin
                        if let first = coordinates.first {
                            Annotation("Start", coordinate: first) {
                                Image(systemName: "flag.fill")
                                    .foregroundStyle(.green)
                                    .font(.title3)
                            }
                        }

                        // Finish pin
                        if let last = coordinates.last, coordinates.count > 1 {
                            Annotation("Finish", coordinate: last) {
                                Image(systemName: "flag.checkered")
                                    .foregroundStyle(.red)
                                    .font(.title3)
                            }
                        }

                        // Split markers (hidden in edit mode)
                        if !isEditingPins {
                            ForEach(splitMarkers) { marker in
                                Annotation("", coordinate: marker.coordinate) {
                                    VStack(spacing: 2) {
                                        Text(marker.label)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(.blue.opacity(0.8)))
                                        if !marker.timeLabel.isEmpty {
                                            Text(marker.timeLabel)
                                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                                .foregroundStyle(.primary)
                                                .padding(.horizontal, 3)
                                                .padding(.vertical, 1)
                                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 3))
                                        }
                                    }
                                }
                            }
                        }

                        // Checkpoint pins
                        ForEach(sortedCheckpoints, id: \.id) { checkpoint in
                            Annotation("", coordinate: CLLocationCoordinate2D(latitude: checkpoint.latitude, longitude: checkpoint.longitude)) {
                                VStack(spacing: 2) {
                                    Image(systemName: isEditingPins ? "xmark.circle.fill" : "mappin")
                                        .font(.system(size: isEditingPins ? 22 : 16, weight: .bold))
                                        .foregroundStyle(isEditingPins ? .red : .orange)
                                    Text("\(checkpoint.order + 1)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(isEditingPins ? .red : .orange)
                                }
                                .onTapGesture {
                                    if isEditingPins {
                                        checkpointToDelete = checkpoint
                                        showDeleteCheckpointConfirmation = true
                                    }
                                }
                                .onLongPressGesture {
                                    checkpointToDelete = checkpoint
                                    showDeleteCheckpointConfirmation = true
                                }
                            }
                        }
                    }
                    .onTapGesture { position in
                        guard isEditingPins,
                              let tappedCoord = proxy.convert(position, from: .local) else { return }
                        // Snap to the nearest point on the route path
                        if let snapped = nearestPointOnRoute(to: tappedCoord, coordinates: coordinates) {
                            newCheckpointLabel = "Checkpoint \(sortedCheckpoints.count + 1)"
                            pendingCheckpointCoordinate = snapped
                            showCheckpointLabelAlert = true
                        }
                    }
                }
                .frame(height: isEditingPins ? 400 : 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .top) {
                    if isEditingPins {
                        Text("Tap the route to add a pin, tap a pin to remove it")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.top, 8)
                    }
                }
            } else {
                ContentUnavailableView("No Route Data", systemImage: "map",
                                       description: Text("No GPS data available for this route."))
                    .frame(height: 200)
            }
        }
    }

    // MARK: - Edit Pins

    private var editPinsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Checkpoints")
                .font(.headline)

            Toggle("Loop Route", isOn: Binding(
                get: { route.isLoopRoute },
                set: { route.isLoopRoute = $0; try? modelContext.save() }
            ))
            .font(.subheadline)

            if sortedCheckpoints.isEmpty {
                Text("No pins yet. Tap on the route to add one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedCheckpoints, id: \.id) { checkpoint in
                    HStack {
                        Image(systemName: "mappin")
                            .foregroundStyle(.orange)
                        Text("\(checkpoint.order + 1). \(checkpoint.label)")
                            .font(.subheadline)
                        Spacer()
                        Button {
                            checkpointToDelete = checkpoint
                            showDeleteCheckpointConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial))
                }
            }
        }
    }

    // MARK: - Timing Stats

    private var timingStatsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let best = bestTime {
                timingStat(value: best.asDuration(), label: "Best")
            }
            if let avg = averageTime {
                timingStat(value: avg.asDuration(), label: "Average")
            }
            if let last = lastRunTime {
                timingStat(value: last.asDuration(), label: "Last")
            }
        }
    }

    private func timingStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.regularMaterial))
    }

    // MARK: - Detail Tabs (Splits / Runs)

    private var detailTabSection: some View {
        VStack(spacing: 12) {
            Picker("Detail", selection: $selectedDetailTab) {
                ForEach(RouteDetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            switch selectedDetailTab {
            case .splits:
                splitsTabContent
            case .runs:
                runsTabContent
            }
        }
    }

    private var splitsTabContent: some View {
        Group {
            if let benchmarkRun = displayRun, !benchmarkRun.splits.isEmpty {
                SplitTableView(
                    splits: benchmarkSplitDisplayData(for: benchmarkRun),
                    fastestSplitIndex: fastestSplitIndex(for: benchmarkRun),
                    slowestSplitIndex: slowestSplitIndex(for: benchmarkRun),
                    unitSystem: unitSystem,
                    splitDistance: splitDistance
                )
                .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
            } else {
                Text("No split data yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
    }

    private var runsTabContent: some View {
        VStack(spacing: 8) {
            if sortedRuns.isEmpty {
                Text("No runs yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ForEach(sortedRuns, id: \.id) { run in
                    NavigationLink(destination: RunSummaryView(run: run)) {
                        runRow(run)
                    }
                }
            }
        }
    }

    // MARK: - Route Performance Chart

    private var paceTrendSection: some View {
        let points = chartDataPoints

        return VStack(spacing: 16) {
            // Chart card (first)
            VStack(alignment: .leading, spacing: 8) {
                Text("Performance")
                    .font(.headline)

                if points.count >= 2 {
                    Chart {
                        ForEach(points) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value(selectedChartMetric.yLabel(unitSystem: unitSystem), point.yValue),
                                series: .value("Series", "data")
                            )
                            .foregroundStyle(.blue.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 2))

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value(selectedChartMetric.yLabel(unitSystem: unitSystem), point.yValue)
                            )
                            .foregroundStyle(.blue)
                            .symbolSize(30)
                        }

                        ForEach(chartTrendPoints) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value(selectedChartMetric.yLabel(unitSystem: unitSystem), point.yValue),
                                series: .value("Series", "trend")
                            )
                            .foregroundStyle(.red)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartLegend(.hidden)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(selectedChartMetric.formatYAxis(v, unitSystem: unitSystem))
                                }
                            }
                        }
                    }
                    .chartYAxisLabel(selectedChartMetric.yLabel(unitSystem: unitSystem))
                    .frame(height: 220)

                    // Trend line picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trend Line")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Trend Line", selection: $chartTrendLine) {
                            ForEach(TrendLineType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } else if points.count == 1 {
                    Text("Run this route once more to see trends.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    Text(selectedChartMetric.isCheckpointMetric
                         ? "No checkpoint data yet. Run this route to record times."
                         : "Run this route at least twice to see trends.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Metric / checkpoint picker card (second)
            VStack(spacing: 0) {
                HStack {
                    Text("Metric")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider()

                Picker("Metric", selection: $selectedChartMetric) {
                    ForEach(RouteChartMetric.allCases) { metric in
                        Text(metric.label).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if selectedChartMetric.isCheckpointMetric {
                    let withData = checkpointsWithData
                    Divider().padding(.leading)
                    if withData.isEmpty {
                        Text("No checkpoint data yet. Run this route to record times.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(withData, id: \.id) { cp in
                                    let isSelected = checkpointPickerBinding.wrappedValue == cp.id
                                    Button {
                                        selectedCheckpointID = cp.id
                                    } label: {
                                        VStack(spacing: 2) {
                                            Text(cp.label)
                                                .font(.caption.weight(.medium))
                                            if let coords = routeCoordinates, coords.count >= 2 {
                                                let dist = cumulativeDistanceAlongRoute(
                                                    to: CLLocationCoordinate2D(latitude: cp.latitude, longitude: cp.longitude),
                                                    coordinates: coords
                                                )
                                                Text(dist.asDistance(unit: unitSystem))
                                                    .font(.caption2)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                    }
                }

                Spacer().frame(height: 4)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func runRow(_ run: Run) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(run.startDate.runDateDisplay())
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                Text(run.distanceMeters.asDistance(unit: unitSystem))
                Text("·").foregroundStyle(.secondary)
                Text(run.durationSeconds.asCompactDuration())
                Text("·").foregroundStyle(.secondary)
                let pace = run.distanceMeters > 0
                    ? (run.durationSeconds / run.distanceMeters).asPace(unit: unitSystem)
                    : "— —"
                Text(pace)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.regularMaterial))
    }

    // MARK: - Actions

    private var actionsSection: some View {
        HStack(spacing: 20) {
            Button {
                renameText = route.name
                showRenameAlert = true
            } label: {
                Label("Rename", systemImage: "pencil")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 8)
    }

    // MARK: - Data Helpers

    private var sortedRuns: [Run] {
        route.runs.sorted { $0.startDate > $1.startDate }
    }

    /// The display run for map/splits: benchmark or best pace run
    private var displayRun: Run? {
        if let benchmarkID = route.benchmarkRunID,
           let run = route.runs.first(where: { $0.id == benchmarkID && !$0.routePoints.isEmpty }) {
            return run
        }
        return route.runs
            .filter { !$0.routePoints.isEmpty && !$0.splits.isEmpty }
            .sorted { ($0.averagePaceSecondsPerKm ?? .infinity) < ($1.averagePaceSecondsPerKm ?? .infinity) }
            .first
    }

    private var routeCoordinates: [CLLocationCoordinate2D]? {
        guard let run = displayRun else { return nil }
        var points = run.routePoints.sorted { $0.distanceFromStart < $1.distanceFromStart }
        if let maxDist = route.singleLapMaxDistance {
            points = points.filter { $0.distanceFromStart <= maxDist }
        }
        return points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var bestTime: Double? {
        route.runs.filter { $0.distanceMeters > 0 }
            .min(by: { $0.durationSeconds < $1.durationSeconds })?.durationSeconds
    }

    private var averageTime: Double? {
        let durations = route.runs.filter { $0.distanceMeters > 0 }.map(\.durationSeconds)
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }

    private var lastRunTime: Double? {
        route.runs.sorted { $0.startDate > $1.startDate }.first?.durationSeconds
    }

    private var averagePace: Double? {
        let paces = route.runs.compactMap { run -> Double? in
            guard run.distanceMeters > 0 else { return nil }
            return run.durationSeconds / run.distanceMeters
        }
        guard !paces.isEmpty else { return nil }
        return paces.reduce(0, +) / Double(paces.count)
    }

    // MARK: - Split Markers

    private struct RouteSplitMarker: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
        let label: String
        let timeLabel: String
    }

    private var splitMarkers: [RouteSplitMarker] {
        guard let run = displayRun else { return [] }
        var sortedPoints = run.routePoints.sorted { $0.distanceFromStart < $1.distanceFromStart }
        if let maxDist = route.singleLapMaxDistance {
            sortedPoints = sortedPoints.filter { $0.distanceFromStart <= maxDist }
        }
        guard !sortedPoints.isEmpty else { return [] }

        let splitDistMeters = splitDistance.metersValue(for: unitSystem)
        let sortedSplits = run.splits.sorted { $0.splitIndex < $1.splitIndex }
        let unitLabel = unitSystem == .imperial ? "Mi" : "Km"

        var markers: [RouteSplitMarker] = []
        var cumulativeTime: Double = 0

        for split in sortedSplits where !split.isPartial {
            cumulativeTime += split.durationSeconds
            let boundaryDistance = Double(split.splitIndex) * splitDistMeters

            // Skip splits beyond the single-lap boundary
            if let maxDist = route.singleLapMaxDistance, boundaryDistance > maxDist {
                continue
            }

            // Find closest route point
            if let closest = sortedPoints.min(by: { abs($0.distanceFromStart - boundaryDistance) < abs($1.distanceFromStart - boundaryDistance) }) {
                let label: String
                switch splitDistance {
                case .full:
                    label = "\(unitLabel) \(split.splitIndex)"
                case .half:
                    label = "½ \(unitLabel) \(split.splitIndex)"
                case .quarter:
                    label = "¼ \(unitLabel) \(split.splitIndex)"
                }

                markers.append(RouteSplitMarker(
                    coordinate: CLLocationCoordinate2D(latitude: closest.latitude, longitude: closest.longitude),
                    label: label,
                    timeLabel: split.durationSeconds.asCompactDuration()
                ))
            }
        }

        return markers
    }

    // MARK: - Benchmark Split Data for SplitTableView

    private func benchmarkSplitDisplayData(for run: Run) -> [SplitDisplayData] {
        let sorted = run.splits.sorted { $0.splitIndex < $1.splitIndex }
        var result: [SplitDisplayData] = []
        var cumulative: Double = 0
        for split in sorted {
            cumulative += split.distanceMeters
            result.append(SplitDisplayData(
                index: split.splitIndex,
                distanceMeters: split.distanceMeters,
                cumulativeDistanceMeters: cumulative,
                durationSeconds: split.durationSeconds,
                paceSecondsPerMeter: split.distanceMeters > 0
                    ? split.durationSeconds / split.distanceMeters : 0,
                elevationGainMeters: split.elevationGainMeters,
                elevationLossMeters: split.elevationLossMeters,
                averageCadence: split.averageCadence,
                isPartial: split.isPartial,
                isCoolDown: split.isCoolDown
            ))
        }
        return result
    }

    private func fastestSplitIndex(for run: Run) -> Int? {
        let fullSplits = run.splits.filter { !$0.isPartial && $0.distanceMeters > 0 }
        return fullSplits.min(by: {
            ($0.durationSeconds / $0.distanceMeters) < ($1.durationSeconds / $1.distanceMeters)
        })?.splitIndex
    }

    private func slowestSplitIndex(for run: Run) -> Int? {
        let fullSplits = run.splits.filter { !$0.isPartial && $0.distanceMeters > 0 }
        return fullSplits.max(by: {
            ($0.durationSeconds / $0.distanceMeters) < ($1.durationSeconds / $1.distanceMeters)
        })?.splitIndex
    }

    // MARK: - Map Camera

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

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.002),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.002)
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }

    // MARK: - Route Chart Data

    /// Only checkpoints that have at least one RunCheckpointResult across all runs.
    private var checkpointsWithData: [RouteCheckpoint] {
        let cpIDsWithData = Set(
            route.runs.flatMap { run in
                run.checkpointResults.compactMap { $0.checkpoint?.id }
            }
        )
        return sortedCheckpoints.filter { cpIDsWithData.contains($0.id) }
    }

    /// Binding that auto-defaults to the first checkpoint with data if the current selection is nil or stale.
    private var checkpointPickerBinding: Binding<UUID?> {
        Binding(
            get: {
                let cps = checkpointsWithData
                if let sel = selectedCheckpointID, cps.contains(where: { $0.id == sel }) {
                    return sel
                }
                return cps.first?.id
            },
            set: { selectedCheckpointID = $0 }
        )
    }

    private struct RouteChartPoint: Identifiable {
        let id: UUID
        let date: Date
        let yValue: Double
    }

    private var chartDataPoints: [RouteChartPoint] {
        switch selectedChartMetric {
        case .checkpointTime:
            return checkpointTimePoints
        case .pace:
            return pacePoints
        case .duration:
            return durationPoints
        }
    }

    private var checkpointTimePoints: [RouteChartPoint] {
        // Resolve the effective checkpoint ID (mirrors the picker binding)
        let cps = checkpointsWithData
        let effectiveID: UUID
        if let sel = selectedCheckpointID, cps.contains(where: { $0.id == sel }) {
            effectiveID = sel
        } else if let first = cps.first?.id {
            effectiveID = first
        } else {
            return []
        }
        return route.runs
            .sorted { $0.startDate < $1.startDate }
            .compactMap { run in
                guard let result = run.checkpointResults
                    .first(where: { $0.checkpoint?.id == effectiveID }) else { return nil }
                return RouteChartPoint(
                    id: run.id,
                    date: run.startDate,
                    yValue: result.elapsedSeconds / 60.0
                )
            }
    }

    private var pacePoints: [RouteChartPoint] {
        route.runs
            .filter { $0.distanceMeters > 0 }
            .sorted { $0.startDate < $1.startDate }
            .map { run in
                let secondsPerMeter = run.durationSeconds / run.distanceMeters
                let secondsPerUnit = secondsPerMeter * unitSystem.metersPerDistanceUnit
                return RouteChartPoint(
                    id: run.id,
                    date: run.startDate,
                    yValue: secondsPerUnit / 60.0
                )
            }
    }

    private var durationPoints: [RouteChartPoint] {
        route.runs
            .filter { $0.distanceMeters > 0 }
            .sorted { $0.startDate < $1.startDate }
            .map { run in
                RouteChartPoint(
                    id: run.id,
                    date: run.startDate,
                    yValue: run.durationSeconds / 60.0
                )
            }
    }

    private var chartTrendPoints: [RouteChartPoint] {
        let points = chartDataPoints
        guard chartTrendLine != .none, points.count >= 2 else { return [] }

        let rawXs = points.map { $0.date.timeIntervalSince1970 }
        let ys = points.map(\.yValue)
        let n = Double(rawXs.count)
        let xMin = rawXs.min()!
        let xMax = rawXs.max()!
        guard xMax > xMin else { return [] }

        // Center x values to avoid numerical overflow with timestamps
        let xMean = rawXs.reduce(0, +) / n
        let xs = rawXs.map { $0 - xMean }

        let steps = 50
        let evalXsRaw = (0...steps).map { xMin + (xMax - xMin) * Double($0) / Double(steps) }
        let evalXs = evalXsRaw.map { $0 - xMean }

        let predicted: [Double]

        switch chartTrendLine {
        case .none:
            return []
        case .linear:
            let sumX = xs.reduce(0, +)
            let sumY = ys.reduce(0, +)
            let sumXY = zip(xs, ys).map(*).reduce(0, +)
            let sumX2 = xs.map { $0 * $0 }.reduce(0, +)
            let denom = n * sumX2 - sumX * sumX
            guard denom != 0 else { return [] }
            let m = (n * sumXY - sumX * sumY) / denom
            let b = (sumY - m * sumX) / n
            predicted = evalXs.map { m * $0 + b }
        case .quadratic:
            let sumX = xs.reduce(0, +)
            let sumX2 = xs.map { $0 * $0 }.reduce(0, +)
            let sumX3 = xs.map { $0 * $0 * $0 }.reduce(0, +)
            let sumX4 = xs.map { pow($0, 4) }.reduce(0, +)
            let sumY = ys.reduce(0, +)
            let sumXY = zip(xs, ys).map(*).reduce(0, +)
            let sumX2Y = zip(xs, ys).map { $0 * $0 * $1 }.reduce(0, +)
            let det = n * (sumX2 * sumX4 - sumX3 * sumX3)
                    - sumX * (sumX * sumX4 - sumX3 * sumX2)
                    + sumX2 * (sumX * sumX3 - sumX2 * sumX2)
            guard abs(det) > 1e-15 else { return [] }
            let detC = sumY * (sumX2 * sumX4 - sumX3 * sumX3)
                     - sumX * (sumXY * sumX4 - sumX3 * sumX2Y)
                     + sumX2 * (sumXY * sumX3 - sumX2 * sumX2Y)
            let detB = n * (sumXY * sumX4 - sumX3 * sumX2Y)
                     - sumY * (sumX * sumX4 - sumX3 * sumX2)
                     + sumX2 * (sumX * sumX2Y - sumXY * sumX2)
            let detA = n * (sumX2 * sumX2Y - sumXY * sumX3)
                     - sumX * (sumX * sumX2Y - sumXY * sumX2)
                     + sumY * (sumX * sumX3 - sumX2 * sumX2)
            let a = detA / det
            let b = detB / det
            let c = detC / det
            predicted = evalXs.map { a * $0 * $0 + b * $0 + c }
        }

        return zip(evalXsRaw, predicted).map { x, y in
            RouteChartPoint(
                id: UUID(),
                date: Date(timeIntervalSince1970: x),
                yValue: y
            )
        }
    }

    // MARK: - Checkpoint Helpers

    private var sortedCheckpoints: [RouteCheckpoint] {
        // Query the model context directly instead of using the relationship,
        // because route.checkpoints can contain invalidated/ghost references
        // that crash on property access.
        let routeID = route.id
        let descriptor = FetchDescriptor<RouteCheckpoint>(
            predicate: #Predicate { $0.namedRoute?.id == routeID },
            sortBy: [SortDescriptor(\RouteCheckpoint.order)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Find the nearest point on the route polyline to a tapped coordinate.
    /// Only returns a result if the tap is within ~50 meters of the route.
    private func nearestPointOnRoute(to tap: CLLocationCoordinate2D, coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        let tapLocation = CLLocation(latitude: tap.latitude, longitude: tap.longitude)
        var bestDistance = Double.greatestFiniteMagnitude
        var bestPoint: CLLocationCoordinate2D?

        for i in 0..<(coordinates.count - 1) {
            let projected = projectPointOnSegment(
                point: tap,
                segStart: coordinates[i],
                segEnd: coordinates[i + 1]
            )
            let dist = tapLocation.distance(from: CLLocation(latitude: projected.latitude, longitude: projected.longitude))
            if dist < bestDistance {
                bestDistance = dist
                bestPoint = projected
            }
        }

        // Only accept if within 50 meters of the route
        guard bestDistance < 50, let point = bestPoint else { return nil }
        return point
    }

    /// Project a point onto a line segment, returning the closest point on that segment.
    private func projectPointOnSegment(point: CLLocationCoordinate2D, segStart: CLLocationCoordinate2D, segEnd: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let dx = segEnd.latitude - segStart.latitude
        let dy = segEnd.longitude - segStart.longitude
        let lengthSq = dx * dx + dy * dy
        guard lengthSq > 0 else { return segStart }

        let t = max(0, min(1, ((point.latitude - segStart.latitude) * dx + (point.longitude - segStart.longitude) * dy) / lengthSq))
        return CLLocationCoordinate2D(
            latitude: segStart.latitude + t * dx,
            longitude: segStart.longitude + t * dy
        )
    }

    private func addCheckpoint(at coordinate: CLLocationCoordinate2D, label: String) {
        let trimmedLabel = label.trimmingCharacters(in: .whitespaces)
        let existing = sortedCheckpoints
        let finalLabel = trimmedLabel.isEmpty ? "Checkpoint \(existing.count + 1)" : String(trimmedLabel.prefix(30))

        // Determine order by finding where this point falls along the route
        let order = orderForNewCheckpoint(at: coordinate)

        // Shift existing checkpoints at or after this order
        for cp in existing where cp.order >= order {
            cp.order += 1
        }

        let bearing = approachBearing(at: coordinate)

        let checkpoint = RouteCheckpoint(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            label: finalLabel,
            order: order,
            expectedApproachBearing: bearing,
            namedRoute: route
        )
        modelContext.insert(checkpoint)
        try? modelContext.save()
    }

    /// Compute the expected approach bearing at a coordinate by finding the nearest route segment.
    private func approachBearing(at coordinate: CLLocationCoordinate2D) -> Double? {
        guard let coordinates = routeCoordinates, coordinates.count >= 2 else { return nil }

        let tapLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var bestDistance = Double.greatestFiniteMagnitude
        var bestSegStart: CLLocationCoordinate2D?
        var bestSegEnd: CLLocationCoordinate2D?

        for i in 0..<(coordinates.count - 1) {
            let projected = projectPointOnSegment(
                point: coordinate,
                segStart: coordinates[i],
                segEnd: coordinates[i + 1]
            )
            let dist = tapLocation.distance(from: CLLocation(latitude: projected.latitude, longitude: projected.longitude))
            if dist < bestDistance {
                bestDistance = dist
                bestSegStart = coordinates[i]
                bestSegEnd = coordinates[i + 1]
            }
        }

        guard let segStart = bestSegStart, let segEnd = bestSegEnd else { return nil }
        return BearingUtils.bearing(from: segStart, to: segEnd)
    }

    /// Determine the correct order index for a new checkpoint based on its position along the route path.
    private func orderForNewCheckpoint(at coordinate: CLLocationCoordinate2D) -> Int {
        guard let coordinates = routeCoordinates, coordinates.count >= 2 else {
            return sortedCheckpoints.count
        }

        // Find cumulative distance along route to the new point
        let newDist = cumulativeDistanceAlongRoute(to: coordinate, coordinates: coordinates)

        // Compare with existing checkpoints
        let existing = sortedCheckpoints
        for (i, cp) in existing.enumerated() {
            let cpCoord = CLLocationCoordinate2D(latitude: cp.latitude, longitude: cp.longitude)
            let cpDist = cumulativeDistanceAlongRoute(to: cpCoord, coordinates: coordinates)
            if newDist < cpDist {
                return i
            }
        }
        return existing.count
    }

    /// Calculate cumulative distance along route to the nearest projection of a point.
    private func cumulativeDistanceAlongRoute(to point: CLLocationCoordinate2D, coordinates: [CLLocationCoordinate2D]) -> Double {
        var cumulativeDist: Double = 0
        var bestTotalDist: Double = 0
        var bestSegDist = Double.greatestFiniteMagnitude
        let loc = CLLocation(latitude: point.latitude, longitude: point.longitude)

        for i in 0..<(coordinates.count - 1) {
            let segStart = coordinates[i]
            let segEnd = coordinates[i + 1]
            let projected = projectPointOnSegment(point: point, segStart: segStart, segEnd: segEnd)
            let dist = loc.distance(from: CLLocation(latitude: projected.latitude, longitude: projected.longitude))

            if dist < bestSegDist {
                bestSegDist = dist
                let startLoc = CLLocation(latitude: segStart.latitude, longitude: segStart.longitude)
                let projLoc = CLLocation(latitude: projected.latitude, longitude: projected.longitude)
                bestTotalDist = cumulativeDist + startLoc.distance(from: projLoc)
            }

            let startLoc = CLLocation(latitude: segStart.latitude, longitude: segStart.longitude)
            let endLoc = CLLocation(latitude: segEnd.latitude, longitude: segEnd.longitude)
            cumulativeDist += startLoc.distance(from: endLoc)
        }

        return bestTotalDist
    }

    private func removeCheckpoint(_ checkpoint: RouteCheckpoint) {
        let removedOrder = checkpoint.order
        let removedID = checkpoint.id

        // Delete first, then save so the fetch in sortedCheckpoints won't see it
        modelContext.delete(checkpoint)
        try? modelContext.save()

        // Reorder remaining checkpoints using a safe fetch
        let remaining = sortedCheckpoints.filter { $0.id != removedID }
        for cp in remaining {
            if cp.order > removedOrder {
                cp.order -= 1
            }
        }
        try? modelContext.save()
    }

    // MARK: - Route Actions

    private func renameRoute() {
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        route.name = String(trimmed.prefix(50))
        try? modelContext.save()
    }

    private func deleteRoute() {
        let service = RunPersistenceService(modelContext: modelContext)
        service.deleteNamedRoute(route)
        dismiss()
    }
}
