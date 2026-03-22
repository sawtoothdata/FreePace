//
//  SettingsView.swift
//  Run-Tracker
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    @AppStorage("splitDistance") private var splitDistance: SplitDistance = .full
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("audioCuesEnabled") private var audioCuesEnabled: Bool = true
    @AppStorage("cueAtSplits") private var cueAtSplits: Bool = true
    @AppStorage("cueAtTimeIntervals") private var cueAtTimeIntervals: Bool = false
    @AppStorage("audioCueIntervalMinutes") private var audioCueIntervalMinutes: Int = 5
    @AppStorage("timeMarkersEnabled") private var timeMarkersEnabled: Bool = false
    @AppStorage("timeMarkerInterval") private var timeMarkerInterval: Int = 5
    @AppStorage("enabledCueFields") private var enabledCueFields: String = AudioCueConfigStorage.defaultFields

    @State private var showClearCacheConfirmation = false
    @State private var bulkExportURLs: [URL] = []
    @State private var showBulkExportShare = false
    @State private var isExporting = false

    private let cacheService = MapTileCacheService.shared

    var body: some View {
        NavigationStack {
            List {
                unitsSection
                mapSection
                audioCuesSection
                appearanceSection
                dataSection
                offlineMapsSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showBulkExportShare) {
                if !bulkExportURLs.isEmpty {
                    ShareSheet(items: bulkExportURLs)
                }
            }
            .alert("Clear Map Cache", isPresented: $showClearCacheConfirmation) {
                Button("Clear", role: .destructive) {
                    cacheService.clearCache()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all cached map tiles. You will need to re-download tiles for offline use.")
            }
        }
    }

    // MARK: - Units Section

    private var unitsSection: some View {
        Section {
            Picker("Units", selection: $unitSystem) {
                Text("Imperial").tag(UnitSystem.imperial)
                Text("Metric").tag(UnitSystem.metric)
            }
            .pickerStyle(.segmented)

            Text(unitPreviewText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Split Distance", selection: $splitDistance) {
                ForEach(SplitDistance.allCases, id: \.self) { distance in
                    Text(distance.displayName(for: unitSystem)).tag(distance)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Units")
        }
    }

    private var unitPreviewText: String {
        let dist = unitSystem.distanceUnit
        let pace = unitSystem.paceUnit
        let elev = unitSystem.elevationUnit
        return "Distance: \(dist) · Pace: \(pace) · Elevation: \(elev)"
    }

    // MARK: - Map Section

    private var mapSection: some View {
        Section {
            Toggle("Time Markers", isOn: $timeMarkersEnabled)

            if timeMarkersEnabled {
                Picker("Interval", selection: $timeMarkerInterval) {
                    ForEach(TimeMarkerInterval.allCases, id: \.rawValue) { interval in
                        Text(interval.displayName).tag(interval.rawValue)
                    }
                }
            }
        } header: {
            Text("Map")
        } footer: {
            Text("Time markers are dropped on the map at the selected interval during a run.")
        }
    }

    // MARK: - Audio Cues Section

    private var audioCuesSection: some View {
        Section {
            Toggle("Audio Cues", isOn: $audioCuesEnabled)

            if audioCuesEnabled {
                Toggle("At each split", isOn: $cueAtSplits)

                Toggle("At time intervals", isOn: $cueAtTimeIntervals)

                if cueAtTimeIntervals {
                    Picker("Interval", selection: $audioCueIntervalMinutes) {
                        ForEach(AudioCueInterval.allCases, id: \.rawValue) { interval in
                            Text(interval.displayName).tag(interval.rawValue)
                        }
                    }
                }

                if cueAtSplits || cueAtTimeIntervals {
                    DisclosureGroup("Cue Info") {
                        ForEach(AudioCueField.baseFields, id: \.id) { field in
                            Toggle(field.displayName, isOn: cueFieldBinding(for: field))
                        }
                    }

                    DisclosureGroup("Coach Mode Comparisons") {
                        ForEach(AudioCueField.coachFields, id: \.id) { field in
                            Toggle(field.displayName, isOn: cueFieldBinding(for: field))
                        }
                    }
                }
            }
        } header: {
            Text("Audio Cues")
        } footer: {
            Text("Audio cues announce your pace and distance during a run. Coach comparisons are only spoken when coach mode is active on a named route.")
        }
    }

    private func cueFieldBinding(for field: AudioCueField) -> Binding<Bool> {
        Binding(
            get: {
                AudioCueConfigStorage.parseFields(enabledCueFields).contains(field)
            },
            set: { enabled in
                var fields = AudioCueConfigStorage.parseFields(enabledCueFields)
                if enabled {
                    fields.insert(field)
                } else {
                    fields.remove(field)
                }
                enabledCueFields = AudioCueConfigStorage.serialize(fields)
            }
        )
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: $appearanceMode) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Appearance")
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section {
            Button {
                exportAllRuns()
            } label: {
                HStack {
                    Label("Export All Runs", systemImage: "square.and.arrow.up")
                    Spacer()
                    if isExporting {
                        ProgressView()
                    }
                }
            }
            .disabled(isExporting)
        } header: {
            Text("Data")
        } footer: {
            Text("Export all runs as individual GPX files for backup or transfer to another app.")
        }
    }

    private func exportAllRuns() {
        isExporting = true
        let service = RunPersistenceService(modelContext: modelContext)
        let runs = service.fetchAllRunsSorted()

        guard !runs.isEmpty else {
            isExporting = false
            return
        }

        // Create a temporary directory for bulk export
        let exportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RunTracker_Export_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

        var urls: [URL] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        for run in runs {
            let gpxString = GPXExportService.generateGPX(from: run)
            let filename = "RunTracker_\(dateFormatter.string(from: run.startDate)).gpx"
            let fileURL = exportDir.appendingPathComponent(filename)
            try? gpxString.write(to: fileURL, atomically: true, encoding: .utf8)
            urls.append(fileURL)
        }

        bulkExportURLs = urls
        isExporting = false
        showBulkExportShare = true
    }

    // MARK: - Offline Maps Section

    private var offlineMapsSection: some View {
        Section {
            HStack {
                Text("Cache Size")
                Spacer()
                Text(cacheService.formattedCacheSize)
                    .foregroundStyle(.secondary)
            }

            Button("Clear Cache", role: .destructive) {
                showClearCacheConfirmation = true
            }
        } header: {
            Text("Offline Maps")
        } footer: {
            Text("Map tiles for named routes are cached automatically when a run is assigned to a route.")
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
