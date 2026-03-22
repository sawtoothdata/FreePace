//
//  ActiveRunView.swift
//  Run-Tracker
//

import SwiftUI
import MapKit

struct ActiveRunView: View {
    @State var viewModel: ActiveRunVM
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    @AppStorage("mapStyle") private var mapStyleSelection: MapStyleSelection = .standard
    @AppStorage("audioCuesEnabled") private var audioCuesEnabled: Bool = true
    @AppStorage("cueAtSplits") private var cueAtSplits: Bool = true
    @AppStorage("cueAtTimeIntervals") private var cueAtTimeIntervals: Bool = false
    @AppStorage("audioCueIntervalMinutes") private var audioCueIntervalMinutes: Int = 5
    @AppStorage("splitDistance") private var splitDistance: SplitDistance = .full
    @AppStorage("mapZoomLevel") private var mapZoomLevel: Double = 0.001
    @AppStorage("timeMarkersEnabled") private var timeMarkersEnabled: Bool = false
    @AppStorage("timeMarkerInterval") private var timeMarkerInterval: Int = 5
    @AppStorage("activeRunStatDisplay") private var activeRunStatDisplay: String = "total"
    @AppStorage("enabledCueFields") private var enabledCueFields: String = AudioCueConfigStorage.defaultFields
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var idleCameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var hasSetIdleCamera = false
    @State private var isUserInteracting = false
    @State private var isProgrammaticCameraChange = false
    @State private var recentInteractionTask: Task<Void, Never>?
    @State private var showSplitToast = false
    @State private var displayedSplit: SplitSnapshot?
    @State private var splitDismissTask: Task<Void, Never>?
    @State private var showStopConfirmation = false
    @State private var savedRun: Run?
    @State private var mapViewMode: MapViewMode = .runner
    @State private var showRouteSelection = false
    @State private var hasNamedRoutes = false
    @State private var lastRun: Run?
    @State private var overlayPanelHeight: CGFloat = 220
    @State private var screenHeight: CGFloat = 0
    @State private var showCheckpointSavedToast = false
    @State private var checkpointSavedLabel: String = ""
    @State private var checkpointDismissTask: Task<Void, Never>?
    @State private var showCheckpointDetectedToast = false
    @State private var detectedCheckpointLabel: String = ""
    @State private var detectedCheckpointElapsed: Double = 0
    @State private var detectedCheckpointDelta: Double?
    @State private var checkpointDetectedDismissTask: Task<Void, Never>?
    @State private var liveZoomSpan: Double?
    @State private var mapColorMode: MapColorMode = .elevation

    var body: some View {
        ZStack(alignment: .top) {
            switch viewModel.runState {
            case .idle:
                idleView
            case .countdown:
                countdownView
            case .active:
                activeView
            case .paused:
                pausedView
            }

            // Split toast overlay
            if showSplitToast, let split = displayedSplit {
                SplitToastView(
                    splitIndex: split.splitIndex,
                    durationSeconds: split.durationSeconds,
                    splitDistance: splitDistance,
                    unitSystem: unitSystem,
                    coachDelta: viewModel.isCoachModeEnabled
                        ? viewModel.routeComparison.paceComparisonDelta
                        : nil
                )
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }

            // Checkpoint toasts (saved or detected)
            if showCheckpointSavedToast {
                CheckpointSavedToastView(label: checkpointSavedLabel)
                    .padding(.top, showSplitToast ? 110 : 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(99)
            }

            if showCheckpointDetectedToast {
                CheckpointToastView(
                    label: detectedCheckpointLabel,
                    elapsedSeconds: detectedCheckpointElapsed,
                    delta: detectedCheckpointDelta
                )
                .padding(.top, showSplitToast ? 110 : 60)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(98)
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            screenHeight = newHeight
        }
        .alert("End this run?", isPresented: $showStopConfirmation) {
            Button("End Run", role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                if let zoom = liveZoomSpan {
                    mapZoomLevel = zoom
                    liveZoomSpan = nil
                }
                viewModel.stopRun()
            }
            Button("Cancel", role: .cancel) { }
        }
        .animation(.easeInOut(duration: 0.3), value: showSplitToast)
        .animation(.easeInOut(duration: 0.3), value: showCheckpointSavedToast)
        .animation(.easeInOut(duration: 0.3), value: showCheckpointDetectedToast)
        .onChange(of: viewModel.latestSplit?.splitIndex) { _, newValue in
            guard newValue != nil, let split = viewModel.latestSplit else { return }
            showSplitToast(for: split)
        }
        .onChange(of: viewModel.checkpointResultCounter) { _, _ in
            guard let cpResult = viewModel.latestCheckpointResult else { return }
            // Only show saved toast for manual drops; detected checkpoints use audio cue only
            if viewModel.latestCheckpointWasManualDrop {
                let label = cpResult.result.checkpoint?.label ?? "Checkpoint"
                showCheckpointSavedToast(label: label)
            }
        }
        .onChange(of: viewModel.completedRun) {
            guard let run = viewModel.completedRun else { return }
            let service = RunPersistenceService(modelContext: modelContext)
            service.saveRun(run)
            // Auto-assign to pre-selected route
            if let route = viewModel.selectedNamedRoute {
                service.assignRoute(route, to: run)
            }
            savedRun = run
            resetIdleState()
            loadLastRun()
        }
        .navigationDestination(item: $savedRun) { run in
            RunSummaryView(run: run)
        }
        .onAppear {
            syncAudioCueSettings()
        }
        .onChange(of: audioCuesEnabled) { _, _ in syncAudioCueSettings() }
        .onChange(of: cueAtSplits) { _, _ in syncAudioCueSettings() }
        .onChange(of: cueAtTimeIntervals) { _, _ in syncAudioCueSettings() }
        .onChange(of: audioCueIntervalMinutes) { _, _ in syncAudioCueSettings() }
        .onChange(of: enabledCueFields) { _, _ in syncAudioCueSettings() }
    }

    private func resetIdleState() {
        hasSetIdleCamera = false
        mapViewMode = .runner
        idleCameraPosition = .userLocation(fallback: .automatic)
        viewModel.initializeLocation()
    }

    private func syncAudioCueSettings() {
        viewModel.audioCueService.isEnabled = audioCuesEnabled
        viewModel.audioCueService.cueAtSplits = cueAtSplits
        viewModel.audioCueService.cueAtTimeIntervals = cueAtTimeIntervals
        viewModel.audioCueService.timeIntervalMinutes = audioCueIntervalMinutes
        viewModel.audioCueService.enabledFields = AudioCueConfigStorage.parseFields(enabledCueFields)
    }

    private func showSplitToast(for split: SplitSnapshot) {
        displayedSplit = split
        showSplitToast = true
        splitDismissTask?.cancel()
        splitDismissTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                showSplitToast = false
            }
        }
    }

    private func showCheckpointSavedToast(label: String) {
        checkpointSavedLabel = label
        showCheckpointSavedToast = true
        checkpointDismissTask?.cancel()
        checkpointDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                showCheckpointSavedToast = false
            }
        }
    }

    private func showCheckpointDetectedToast(label: String, elapsed: Double, delta: Double?) {
        detectedCheckpointLabel = label
        detectedCheckpointElapsed = elapsed
        detectedCheckpointDelta = delta
        showCheckpointDetectedToast = true
        checkpointDetectedDismissTask?.cancel()
        checkpointDetectedDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                showCheckpointDetectedToast = false
            }
        }
    }

    // MARK: - Idle State

    private var idleView: some View {
        ZStack {
            Map(position: $idleCameraPosition) {
                UserAnnotation()
            }
            .mapStyle(MapStyleSelection.standard.mapStyle(for: colorScheme))
            .opacity(0.4)
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 24) {
                    GPSSignalIndicator(
                        horizontalAccuracy: viewModel.currentHorizontalAccuracy
                    )
                    .scaleEffect(2.0)

                    Button {
                        if hasNamedRoutes {
                            showRouteSelection = true
                        } else {
                            viewModel.startCountdown()
                        }
                    } label: {
                        Text("Start")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 150, height: 150)
                            .background(Circle().fill(.green))
                    }

                    // Last run summary
                    if let run = lastRun {
                        lastRunCard(run: run)
                    }
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    overlayPanelHeight = newHeight
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showRouteSelection) {
            RouteSelectionSheet(
                onFreeRun: {
                    viewModel.selectedNamedRoute = nil
                    viewModel.setNamedRoute(nil)
                    viewModel.isCoachModeEnabled = false
                    mapViewMode = .runner
                    viewModel.startCountdown()
                },
                onRouteSelected: { route, coachEnabled in
                    viewModel.selectedNamedRoute = route
                    viewModel.setNamedRoute(route)
                    viewModel.isCoachModeEnabled = coachEnabled && viewModel.routeComparison.hasCoachData
                    mapViewMode = .route
                    viewModel.startCountdown()
                    // Delay to let the map view appear before fitting the route
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        await MainActor.run { showFullRoute() }
                    }
                }
            )
        }
        .onAppear {
            checkForNamedRoutes()
            viewModel.initializeLocation()
        }
        .onDisappear {
            viewModel.pauseIdleLocationIfNotRunning()
        }
        .onChange(of: viewModel.currentUserLocation?.coordinate.latitude) {
            updateIdleCamera()
        }
        .onChange(of: overlayPanelHeight) {
            recenterIdleCamera()
        }
        .onChange(of: screenHeight) {
            recenterIdleCamera()
        }
    }

    // MARK: - Countdown State

    private var countdownView: some View {
        ZStack {
            Map(position: $idleCameraPosition) {
                UserAnnotation()
            }
            .mapStyle(MapStyleSelection.standard.mapStyle(for: colorScheme))
            .ignoresSafeArea()

            // Full-screen tap to skip
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.startRunNow()
                }

            VStack(spacing: 16) {
                Spacer()

                Button {
                    viewModel.startRunNow()
                } label: {
                    VStack(spacing: 8) {
                        Text("\(viewModel.countdownSeconds)")
                            .font(.system(size: 96, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(width: 140, alignment: .center)
                            .id(viewModel.countdownSeconds)
                            .transition(.scale(scale: 1.2).combined(with: .opacity))
                            .animation(.easeOut(duration: 0.8), value: viewModel.countdownSeconds)

                        Text("Tap to skip")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.secondary.opacity(0.5), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    viewModel.cancelCountdown()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(minWidth: 120, minHeight: 44)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .frame(minWidth: 64, minHeight: 44)
                .padding(.bottom, 40)
            }
        }
    }


    // MARK: - Active State

    private var activeView: some View {
        VStack(spacing: 0) {
            // Map area (top ~55%)
            ZStack {
                mapView
                    .frame(maxHeight: .infinity)

                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            OfflineMapBadge()
                        }
                        .padding(12)
                        Spacer()
                        VStack(spacing: 8) {
                            // Runner/Route view toggle (only for named routes)
                            if viewModel.hasActiveNamedRoute {
                                Button {
                                    mapViewMode = mapViewMode == .runner ? .route : .runner
                                    if mapViewMode == .route {
                                        showFullRoute()
                                    } else {
                                        centerOnRunnerForced()
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: mapViewMode == .runner ? "figure.run" : "map")
                                            .font(.system(size: 12, weight: .medium))
                                        Text(mapViewMode == .runner ? "Runner" : "Route")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .overlay(Capsule().stroke(Color.secondary.opacity(0.5), lineWidth: 1))
                                }
                            }

                            // Map style toggle
                            Button {
                                mapStyleSelection = mapStyleSelection == .standard ? .hybrid : .standard
                            } label: {
                                Image(systemName: "square.2.layers.3d")
                                    .font(.system(size: 16, weight: .medium))
                                    .padding(10)
                                    .background(.ultraThinMaterial, in: Circle())
                            }

                            // Re-center button (visible when user has panned)
                            if isUserInteracting {
                                Button {
                                    reCenter()
                                } label: {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .padding(10)
                                        .background(.ultraThinMaterial, in: Circle())
                                }
                            }

                            // Zoom controls
                            VStack(spacing: 0) {
                                Button {
                                    zoomIn()
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .medium))
                                        .frame(width: 36, height: 36)
                                }
                                Divider().frame(width: 28)
                                Button {
                                    zoomOut()
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 16, weight: .medium))
                                        .frame(width: 36, height: 36)
                                }
                            }
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

                        }
                        .padding(12)
                    }
                    Spacer()
                }

                // Map color legend + toggle (bottom-left)
                if !viewModel.elevationRouteSegments.isEmpty || !viewModel.paceRouteSegments.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            VStack(spacing: 6) {
                                if mapColorMode == .pace {
                                    paceLegend
                                } else {
                                    elevationLegend
                                }
                                // Toggle between elevation and pace
                                Button {
                                    mapColorMode = mapColorMode == .elevation ? .pace : .elevation
                                } label: {
                                    Image(systemName: mapColorMode == .pace ? "speedometer" : "mountain.2")
                                        .font(.system(size: 14))
                                        .frame(width: 30, height: 30)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            .padding(12)
                            Spacer()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .layoutPriority(55)

            // Stats dashboard (bottom ~45%)
            statsDashboard
                .layoutPriority(45)
        }
    }

    private var mapView: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            // Named route overlay (dashed, semi-transparent)
            if viewModel.namedRouteCoordinates.count >= 2 {
                MapPolyline(coordinates: viewModel.namedRouteCoordinates)
                    .stroke(.blue.opacity(0.3), style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
            }

            // Benchmark split markers
            ForEach(viewModel.routeComparison.benchmarkSplitMarkers) { marker in
                Annotation("", coordinate: marker.coordinate) {
                    VStack(spacing: 2) {
                        Text(marker.formattedTime)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: Capsule())
                        Circle()
                            .fill(.white)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(.gray, lineWidth: 1.5))
                    }
                }
            }

            // Active run polyline (elevation or pace colored segments)
            let activeSegments = mapColorMode == .pace ? viewModel.paceRouteSegments : viewModel.elevationRouteSegments
            if !activeSegments.isEmpty {
                ForEach(activeSegments) { segment in
                    MapPolyline(coordinates: segment.coordinates)
                        .stroke(segment.color, lineWidth: 4)
                }
            } else if viewModel.displayedRouteCoordinates.count >= 2 {
                // Fallback to solid blue before enough data for elevation coloring
                MapPolyline(coordinates: viewModel.displayedRouteCoordinates)
                    .stroke(.blue, lineWidth: 4)
            }

            // Start marker
            if let first = viewModel.displayedRouteCoordinates.first {
                Annotation("Start", coordinate: first) {
                    Circle()
                        .fill(.green)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }

            // Time markers
            ForEach(viewModel.timeMarkers) { marker in
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

            // Checkpoint pins (all — passed are filled, upcoming are outlined)
            ForEach(Array(viewModel.routeCheckpoints.enumerated()), id: \.element.id) { index, checkpoint in
                let isPassed = index < viewModel.nextCheckpointIndex
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: checkpoint.latitude, longitude: checkpoint.longitude)) {
                    VStack(spacing: 2) {
                        Image(systemName: isPassed ? "mappin.circle.fill" : "mappin")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isPassed ? .orange : .orange.opacity(0.4))
                        Text("\(checkpoint.order + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isPassed ? .orange : .orange.opacity(0.4))
                    }
                }
            }
        }
        .mapStyle(mapStyleSelection.mapStyle(for: colorScheme))
        .onMapCameraChange(frequency: .onEnd) { context in
            if isProgrammaticCameraChange {
                isProgrammaticCameraChange = false
                return
            }
            if (viewModel.runState == .active || viewModel.runState == .paused),
               mapViewMode == .runner {
                let span = context.region.span
                let avgSpan = (span.latitudeDelta + span.longitudeDelta) / 2.0
                liveZoomSpan = avgSpan
            }
        }
        .onChange(of: viewModel.displayedRouteCoordinates.count) {
            if mapViewMode == .runner {
                centerOnRunner()
            }
        }
    }

    private var effectiveZoom: Double {
        liveZoomSpan ?? mapZoomLevel
    }

    private func centerOnRunner() {
        guard !isUserInteracting else { return }
        guard let lastCoord = viewModel.displayedRouteCoordinates.last else { return }
        let span = MKCoordinateSpan(latitudeDelta: effectiveZoom, longitudeDelta: effectiveZoom)
        let region = MKCoordinateRegion(center: lastCoord, span: span)
        isProgrammaticCameraChange = true
        withAnimation(.easeInOut(duration: 0.3)) {
            cameraPosition = .region(region)
        }
    }

    private func showFullRoute() {
        guard !viewModel.namedRouteCoordinates.isEmpty else { return }
        let lats = viewModel.namedRouteCoordinates.map(\.latitude)
        let lons = viewModel.namedRouteCoordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLon - minLon) * 1.3
        )
        let region = MKCoordinateRegion(center: center, span: span)
        isProgrammaticCameraChange = true
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(region)
        }
    }

    private var statsDashboard: some View {
        VStack(spacing: 8) {
            // Selected route name + coach badge
            HStack(spacing: 8) {
                if let routeName = viewModel.selectedNamedRoute?.name {
                    Text(routeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.blue.opacity(0.15)))
                }

                // Coach mode toggle (only when running a named route with prior runs)
                if viewModel.selectedNamedRoute != nil && viewModel.routeComparison.hasCoachData {
                    Button {
                        viewModel.isCoachModeEnabled.toggle()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "figure.run.circle")
                                .font(.system(size: 12))
                            Text("Coach")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(viewModel.isCoachModeEnabled ? .green.opacity(0.2) : .gray.opacity(0.15)))
                        .foregroundStyle(viewModel.isCoachModeEnabled ? .green : .secondary)
                    }
                }
            }
            .padding(.top, 4)

            // Running Only / Total toggle (only show when cool-down has been used)
            if viewModel.hadCoolDownDuringRun {
                Picker("Stats", selection: $activeRunStatDisplay) {
                    Text("Total").tag("total")
                    Text("Running Only").tag("runningOnly")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }

            // Time (largest) with ahead/behind indicator
            ZStack(alignment: .trailing) {
                VStack(spacing: 0) {
                    StatCard(
                        value: displayedDuration.asDuration(),
                        unit: "time",
                        valueFont: .system(size: 48, weight: .bold, design: .monospaced)
                    )
                    if showRunningOnly, displayedDuration != viewModel.elapsedSeconds {
                        Text("(\(viewModel.elapsedSeconds.asDuration()) total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let delta = viewModel.routeComparison.paceComparisonDelta {
                    paceComparisonBadge(delta: delta)
                        .padding(.trailing, 12)
                }
            }
            .padding(.top, 8)

            // Lap indicator for loop routes
            if viewModel.isLoopRoute {
                HStack(spacing: 8) {
                    Text("Lap \(viewModel.currentLap + 1)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let lastLapTime = viewModel.lapTimes.last {
                        Text("Last: \(lastLapTime.asDuration())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 2)
            }

            // 2-column grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                // Distance | Avg Pace
                VStack(spacing: 0) {
                    StatCard(
                        value: formatDisplayedDistance(),
                        unit: unitSystem.distanceUnit
                    )
                    if showRunningOnly, displayedDistance != viewModel.totalDistanceMeters {
                        Text("(\(formatTotalDistance()) total)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                StatCard(
                    value: displayedPace.asPace(unit: unitSystem),
                    unit: "avg"
                )

                // Elevation gain | Elevation loss
                StatCard(
                    value: "\u{2191} " + viewModel.elevationGainMeters.asElevation(unit: unitSystem),
                    unit: "gain"
                )
                StatCard(
                    value: "\u{2193} " + viewModel.elevationLossMeters.asElevation(unit: unitSystem),
                    unit: "loss"
                )

                // Current Pace | Cadence
                StatCard(
                    value: viewModel.isCurrentPaceAvailable
                        ? viewModel.currentPaceSecondsPerMeter.asPace(unit: unitSystem)
                        : "— —",
                    unit: "pace"
                )
                StatCard(
                    value: viewModel.currentCadence != nil
                        ? "\(Int(viewModel.currentCadence!)) spm"
                        : "—",
                    unit: "cadence"
                )
            }
            .padding(.horizontal)

            // Control buttons
            HStack(spacing: 24) {
                // Pause button
                Button {
                    viewModel.pauseRun()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(.orange))
                }

                // Cool Down toggle
                coolDownButton

                // Drop checkpoint button
                checkpointButton

                // Stop button (tap + confirmation)
                Button {
                    showStopConfirmation = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(.red))
                }
            }
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Paused State

    private var pausedView: some View {
        VStack(spacing: 0) {
            // Map area (same as active)
            ZStack(alignment: .topTrailing) {
                mapView
                    .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)
            .layoutPriority(55)

            // Paused stats dashboard
            VStack(spacing: 8) {
                // PAUSED label
                Text("PAUSED")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.top, 8)

                // Pulsing timer
                StatCard(
                    value: viewModel.elapsedSeconds.asDuration(),
                    unit: "time",
                    valueFont: .system(size: 48, weight: .bold, design: .monospaced)
                )
                .opacity(pulseOpacity)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: pulseOpacity
                )
                .onAppear { isPulsing = true }
                .onDisappear { isPulsing = false }

                // 2-column grid (same stats, frozen)
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    StatCard(
                        value: formatDistance(),
                        unit: unitSystem.distanceUnit
                    )
                    StatCard(
                        value: viewModel.averagePaceSecondsPerMeter.asPace(unit: unitSystem),
                        unit: "avg"
                    )
                }
                .padding(.horizontal)

                // Resume / Stop buttons
                HStack(spacing: 24) {
                    Button {
                        viewModel.resumeRun()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(.green))
                    }

                    // Cool Down toggle
                    coolDownButton

                    // Drop checkpoint button
                    checkpointButton

                    // Stop button (tap + confirmation)
                    Button {
                        showStopConfirmation = true
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(.red))
                    }
                }
                .padding(.bottom, 8)
            }
            .background(Color.orange.opacity(0.08))
            .background(Color(.systemBackground))
            .layoutPriority(45)
        }
    }

    @State private var isPulsing = false

    private var pulseOpacity: Double {
        isPulsing ? 0.3 : 1.0
    }

    // MARK: - Elevation Legend

    private var elevationLegend: some View {
        let minElev = viewModel.elevationRange.min.asElevation(unit: unitSystem)
        let maxElev = viewModel.elevationRange.max.asElevation(unit: unitSystem)

        return VStack(alignment: .leading, spacing: 2) {
            Text(maxElev)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
            LinearGradient(
                colors: [
                    ElevationColor.color(for: 1.0),
                    ElevationColor.color(for: 0.66),
                    ElevationColor.color(for: 0.33),
                    ElevationColor.color(for: 0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 12, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(minElev)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var paceLegend: some View {
        let minPace = viewModel.paceRange.min
        let maxPace = viewModel.paceRange.max
        let minPaceStr = formatPaceLegend(minPace, unit: unitSystem)
        let maxPaceStr = formatPaceLegend(maxPace, unit: unitSystem)

        return VStack(alignment: .leading, spacing: 2) {
            Text(maxPaceStr)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
            LinearGradient(
                colors: [
                    PaceColor.color(for: 1.0),
                    PaceColor.color(for: 0.5),
                    PaceColor.color(for: 0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 12, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(minPaceStr)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func formatPaceLegend(_ secondsPerMeter: Double, unit: UnitSystem) -> String {
        guard secondsPerMeter > 0, secondsPerMeter.isFinite else { return "--:--" }
        let secondsPerUnit = secondsPerMeter * unit.metersPerDistanceUnit
        guard secondsPerUnit < 3600 else { return "--:--" }
        let totalSeconds = Int(secondsPerUnit)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Pace Comparison

    private func paceComparisonBadge(delta: Double) -> some View {
        let isAhead = delta < 0
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

    // MARK: - Running Only / Total Display

    private var showRunningOnly: Bool {
        activeRunStatDisplay == "runningOnly"
    }

    private var displayedDistance: Double {
        showRunningOnly ? viewModel.runningOnlyDistanceMeters : viewModel.totalDistanceMeters
    }

    private var displayedDuration: Double {
        showRunningOnly ? viewModel.runningOnlyDurationSeconds : viewModel.elapsedSeconds
    }

    private var displayedPace: Double {
        guard displayedDistance > 0 else { return 0 }
        return displayedDuration / displayedDistance
    }

    private func formatDisplayedDistance() -> String {
        let value = displayedDistance.toDistanceValue(unit: unitSystem)
        return String(format: "%.2f", value)
    }

    private func formatTotalDistance() -> String {
        let value = viewModel.totalDistanceMeters.toDistanceValue(unit: unitSystem)
        return String(format: "%.2f %@", value, unitSystem.distanceUnit)
    }

    // MARK: - Checkpoint Button

    private var checkpointButton: some View {
        let count = viewModel.selectedNamedRoute?.checkpoints.count ?? viewModel.pendingFreeRunCheckpoints.count
        let maxReached = count >= 20
        return Button {
            viewModel.dropCheckpoint()
        } label: {
            Image(systemName: maxReached ? "mappin.slash" : "mappin.and.ellipse")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(maxReached ? .secondary : .blue)
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                )
        }
        .disabled(maxReached)
        .accessibilityLabel(maxReached ? "Max checkpoints reached" : "Drop checkpoint")
    }

    // MARK: - Cool Down Button

    private var coolDownButton: some View {
        Button {
            viewModel.toggleCoolDown()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 22, weight: .medium))
                Text(viewModel.isCoolDownActive ? "Running" : "Walking")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(viewModel.isCoolDownActive ? .blue : .secondary)
            .frame(width: 64, height: 64)
            .background(
                Circle()
                    .fill(viewModel.isCoolDownActive ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
            )
        }
    }

    // MARK: - Helpers

    private func formatDistance() -> String {
        let value = viewModel.totalDistanceMeters.toDistanceValue(unit: unitSystem)
        return String(format: "%.2f", value)
    }

    private func handleUserInteraction() {
        isUserInteracting = true
        recentInteractionTask?.cancel()
        recentInteractionTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                reCenter()
            }
        }
    }

    private func reCenter() {
        isUserInteracting = false
        if let lastCoord = viewModel.displayedRouteCoordinates.last {
            let span = MKCoordinateSpan(latitudeDelta: effectiveZoom, longitudeDelta: effectiveZoom)
            let region = MKCoordinateRegion(center: lastCoord, span: span)
            isProgrammaticCameraChange = true
            withAnimation(.easeInOut(duration: 0.3)) {
                cameraPosition = .region(region)
            }
        } else {
            isProgrammaticCameraChange = true
            cameraPosition = .userLocation(fallback: .automatic)
        }
    }

    private func zoomIn() {
        liveZoomSpan = max(effectiveZoom / 2.0, 0.001)
        centerOnRunnerForced()
    }

    private func zoomOut() {
        liveZoomSpan = min(effectiveZoom * 2.0, 0.5)
        centerOnRunnerForced()
    }

    private func centerOnRunnerForced() {
        if let lastCoord = viewModel.displayedRouteCoordinates.last {
            let span = MKCoordinateSpan(latitudeDelta: effectiveZoom, longitudeDelta: effectiveZoom)
            let region = MKCoordinateRegion(center: lastCoord, span: span)
            isProgrammaticCameraChange = true
            withAnimation(.easeInOut(duration: 0.3)) {
                cameraPosition = .region(region)
            }
        }
    }

    private func checkForNamedRoutes() {
        let service = RunPersistenceService(modelContext: modelContext)
        hasNamedRoutes = !service.fetchAllNamedRoutes().isEmpty
        loadLastRun()
    }

    private func loadLastRun() {
        let service = RunPersistenceService(modelContext: modelContext)
        lastRun = service.fetchAllRunsSorted().first
    }

    private func lastRunCard(run: Run) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Last Run")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(run.startDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.primary)
            }

            Divider().frame(height: 24)

            VStack(spacing: 2) {
                Text(String(format: "%.2f", run.distanceMeters.toDistanceValue(unit: unitSystem)))
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                Text(unitSystem.distanceUnit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 24)

            VStack(spacing: 2) {
                Text((run.averagePaceSecondsPerKm ?? 0) > 0
                    ? ((run.averagePaceSecondsPerKm! / 1000.0).asPace(unit: unitSystem))
                    : "—")
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                Text("pace")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func recenterIdleCamera() {
        guard viewModel.runState == .idle,
              hasSetIdleCamera,
              let location = viewModel.currentUserLocation else { return }
        let center = idleCameraCenter(userCoordinate: location.coordinate)
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        withAnimation(.easeInOut(duration: 0.3)) {
            idleCameraPosition = .region(region)
        }
    }

    private func idleCameraCenter(userCoordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        idleCameraOffsetCenter(
            userCoordinate: userCoordinate,
            latitudeDelta: 0.005,
            screenHeight: screenHeight,
            overlayPanelHeight: overlayPanelHeight
        )
    }

    private func updateIdleCamera() {
        guard !hasSetIdleCamera,
              let location = viewModel.currentUserLocation else { return }
        hasSetIdleCamera = true
        let center = idleCameraCenter(userCoordinate: location.coordinate)
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        withAnimation(.easeInOut(duration: 0.5)) {
            idleCameraPosition = .region(region)
        }
    }
}

// MARK: - Map View Mode

enum MapViewMode {
    case runner  // centered on current position
    case route   // zoomed out to show full named route
}

// MARK: - Map Color Mode

enum MapColorMode {
    case elevation
    case pace
}

// MARK: - Map Style Selection

enum MapStyleSelection: String {
    case standard
    case hybrid

    var mapStyle: MapStyle {
        mapStyle(for: nil)
    }

    func mapStyle(for colorScheme: ColorScheme?) -> MapStyle {
        let isDark = colorScheme == .dark
        switch self {
        case .standard:
            return isDark
                ? .standard(elevation: .realistic, emphasis: .muted)
                : .standard(elevation: .realistic)
        case .hybrid:
            return .hybrid(elevation: .realistic)
        }
    }
}
