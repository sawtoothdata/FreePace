//
//  RunHistoryListView.swift
//  Run-Tracker
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum RunsTab: String, CaseIterable {
    case history = "History"
    case routes = "Routes"
    case explorer = "Explorer"
}

struct RunHistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    @AppStorage("splitDistance") private var splitDistance: SplitDistance = .full
    @State private var viewModel: RunHistoryVM?
    @State private var showFilterSheet = false
    @State private var runToDelete: Run?
    @State private var showDeleteConfirmation = false
    @State private var showFileImporter = false
    @State private var importPreview: GPXImportPreview?
    @State private var importError: String?
    @State private var showImportError = false
    @State private var selectedTab: RunsTab = .history

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedTab) {
                    ForEach(RunsTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch selectedTab {
                case .history:
                    historyContent
                case .routes:
                    routesContent
                case .explorer:
                    explorerContent
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showFilterSheet) {
                if let vm = viewModel {
                    FilterSheetView(viewModel: vm)
                }
            }
            .alert("Delete Run", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let run = runToDelete {
                        viewModel?.deleteRun(run)
                    }
                    runToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    runToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this run? This cannot be undone.")
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = RunHistoryVM(modelContext: modelContext)
                } else {
                    viewModel?.fetchRuns()
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml, .xml],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(item: $importPreview) { preview in
                GPXImportPreviewView(preview: preview)
                    .onDisappear {
                        viewModel?.fetchRuns()
                    }
            }
            .alert("Import Error", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - History Content

    private var historyContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    showFileImporter = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                Spacer()
                Button {
                    showFilterSheet = true
                } label: {
                    Image(systemName: viewModel?.hasActiveFilters == true
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            if let vm = viewModel {
                if vm.runs.isEmpty {
                    emptyState(hasFilters: vm.hasActiveFilters)
                } else {
                    runList(vm: vm)
                }
            } else {
                ProgressView()
            }
        }
    }

    // MARK: - Routes Content

    private var routesContent: some View {
        RouteManagementView()
    }

    // MARK: - Explorer Content

    private var explorerContent: some View {
        DataExplorerView()
    }

    // MARK: - File Import Handler

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let segments = try GPXImportService.parse(url: url)
                let preview = GPXImportService.computeStats(
                    from: segments,
                    unitSystem: unitSystem,
                    splitDistance: splitDistance
                )
                importPreview = preview
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }
        case .failure(let error):
            importError = error.localizedDescription
            showImportError = true
        }
    }

    // MARK: - Empty State

    private func emptyState(hasFilters: Bool) -> some View {
        ContentUnavailableView {
            Label(
                hasFilters ? "No Matching Runs" : "No Runs Yet",
                systemImage: hasFilters ? "magnifyingglass" : "figure.run"
            )
        } description: {
            Text(hasFilters
                 ? "No runs match your filters."
                 : "Lace up and hit Start!")
        } actions: {
            if hasFilters {
                Button("Reset Filters") {
                    viewModel?.resetFilters()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Run List

    private func runList(vm: RunHistoryVM) -> some View {
        List {
            ForEach(vm.runs, id: \.id) { run in
                NavigationLink(destination: RunSummaryView(run: run)) {
                    runRowCard(run)
                }
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    runToDelete = vm.runs[index]
                    showDeleteConfirmation = true
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Run Row Card

    private func runRowCard(_ run: Run) -> some View {
        HStack(spacing: 12) {
            RouteSnapshotView(
                coordinates: run.routePoints
                    .sorted { $0.timestamp < $1.timestamp }
                    .map { ($0.latitude, $0.longitude) },
                size: CGSize(width: 48, height: 48)
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(run.startDate.runDateDisplay())
                        .font(.subheadline.weight(.semibold))

                    if let routeName = run.namedRoute?.name {
                        Text("· \(routeName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Text(run.distanceMeters.asDistance(unit: unitSystem))
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(run.durationSeconds.asCompactDuration())
                    Text("·")
                        .foregroundStyle(.secondary)

                    let pace = run.distanceMeters > 0
                        ? (run.durationSeconds / run.distanceMeters).asPace(unit: unitSystem)
                        : "— —"
                    Text(pace)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Filter Sheet

struct FilterSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: RunHistoryVM
    @State private var localStartDate: Date = Date()
    @State private var localEndDate: Date = Date()
    @State private var hasStartDate: Bool = false
    @State private var hasEndDate: Bool = false
    @State private var minDistanceText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                // Sort section
                Section("Sort By") {
                    Picker("Field", selection: $viewModel.sortField) {
                        ForEach(RunSortField.allCases, id: \.self) { field in
                            Text(field.rawValue).tag(field)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Ascending", isOn: $viewModel.sortAscending)
                }

                // Date filter
                Section("Date Range") {
                    Toggle("From Date", isOn: $hasStartDate)
                    if hasStartDate {
                        DatePicker("From", selection: $localStartDate, displayedComponents: .date)
                    }

                    Toggle("To Date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("To", selection: $localEndDate, displayedComponents: .date)
                    }
                }

                // Distance filter
                Section("Minimum Distance") {
                    TextField("e.g. 5.0", text: $minDistanceText)
                        .keyboardType(.decimalPad)
                }

                // Route filter
                if !viewModel.namedRoutes.isEmpty {
                    Section("Route") {
                        Picker("Route", selection: selectedRouteID) {
                            Text("All Routes").tag(nil as UUID?)
                            ForEach(viewModel.namedRoutes, id: \.id) { route in
                                Text(route.name).tag(route.id as UUID?)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sort & Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        viewModel.resetFilters()
                        hasStartDate = false
                        hasEndDate = false
                        minDistanceText = ""
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        applyFilters()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let start = viewModel.filterStartDate {
                    hasStartDate = true
                    localStartDate = start
                }
                if let end = viewModel.filterEndDate {
                    hasEndDate = true
                    localEndDate = end
                }
                if let minDist = viewModel.filterMinDistanceMeters {
                    minDistanceText = String(format: "%.1f", minDist / 1000.0)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var selectedRouteID: Binding<UUID?> {
        Binding(
            get: { viewModel.filterNamedRoute?.id },
            set: { newID in
                viewModel.filterNamedRoute = viewModel.namedRoutes.first { $0.id == newID }
            }
        )
    }

    private func applyFilters() {
        viewModel.filterStartDate = hasStartDate ? localStartDate : nil
        viewModel.filterEndDate = hasEndDate ? localEndDate : nil

        if let value = Double(minDistanceText), value > 0 {
            // User enters in km, convert to meters
            viewModel.filterMinDistanceMeters = value * 1000.0
        } else {
            viewModel.filterMinDistanceMeters = nil
        }

        viewModel.applyFilters()
    }
}
