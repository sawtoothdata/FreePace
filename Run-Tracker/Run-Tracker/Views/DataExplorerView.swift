//
//  DataExplorerView.swift
//  Run-Tracker
//

import SwiftUI
import SwiftData
import Charts

struct DataExplorerView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    @State private var viewModel: DataExplorerVM?
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var hasStartDate = false
    @State private var hasEndDate = false
    @State private var localStartDate = Date()
    @State private var localEndDate = Date()
    @State private var showRouteFilter = false
    @State private var localSelectedRouteIDs: Set<UUID> = []
    @State private var localIncludeFreeRuns: Bool = false
    @State private var routeDebounceTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let vm = viewModel {
                explorerContent(vm: vm)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = DataExplorerVM(modelContext: modelContext)
            }
        }
    }

    // MARK: - Main Content

    private func explorerContent(vm: DataExplorerVM) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                chartSection(vm: vm)
                summaryStatsRow(vm: vm)
                axisSection(vm: vm)
                filtersSection(vm: vm)
                exportSection(vm: vm)
            }
            .padding()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheetView(items: [url])
            }
        }
    }

    // MARK: - Summary Stats

    private func summaryStatsRow(vm: DataExplorerVM) -> some View {
        HStack(spacing: 12) {
            StatCard(
                value: "\(vm.filteredRuns.count)",
                unit: vm.filteredRuns.count == 1 ? "run" : "runs",
                valueFont: .system(size: 18, weight: .bold, design: .monospaced),
                unitFont: .system(size: 12, weight: .medium)
            )

            let totalDist = vm.filteredRuns.reduce(0.0) { $0 + $1.distanceMeters }
            StatCard(
                value: String(format: "%.1f", totalDist.toDistanceValue(unit: unitSystem)),
                unit: unitSystem.distanceUnit,
                valueFont: .system(size: 18, weight: .bold, design: .monospaced),
                unitFont: .system(size: 12, weight: .medium)
            )

            let avgPace = averagePace(runs: vm.filteredRuns)
            StatCard(
                value: avgPace,
                unit: "min/\(unitSystem.distanceUnit)",
                valueFont: .system(size: 18, weight: .bold, design: .monospaced),
                unitFont: .system(size: 12, weight: .medium)
            )
        }
        .frame(height: 56)
        .padding(.horizontal, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func averagePace(runs: [Run]) -> String {
        let validRuns = runs.filter { $0.distanceMeters > 0 }
        guard !validRuns.isEmpty else { return "—" }
        let totalTime = validRuns.reduce(0.0) { $0 + $1.durationSeconds }
        let totalDist = validRuns.reduce(0.0) { $0 + $1.distanceMeters }
        guard totalDist > 0 else { return "—" }
        let secPerMeter = totalTime / totalDist
        return secPerMeter.asPace(unit: unitSystem)
    }

    // MARK: - Filters

    private func filtersSection(vm: DataExplorerVM) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Filters")
                    .font(.headline)
                Spacer()
                Text("\(vm.filteredRuns.count) \(vm.filteredRuns.count == 1 ? "run" : "runs")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Date Range
            VStack(spacing: 0) {
                Toggle("From Date", isOn: $hasStartDate)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .onChange(of: hasStartDate) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            vm.startDate = hasStartDate ? localStartDate : nil
                            vm.refresh(unitSystem: unitSystem)
                        }
                    }

                if hasStartDate {
                    Divider().padding(.leading)
                    DatePicker("From", selection: $localStartDate, displayedComponents: .date)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .onChange(of: localStartDate) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                vm.startDate = localStartDate
                                vm.refresh(unitSystem: unitSystem)
                            }
                        }
                }

                Divider().padding(.leading)

                Toggle("To Date", isOn: $hasEndDate)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .onChange(of: hasEndDate) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            vm.endDate = hasEndDate ? localEndDate : nil
                            vm.refresh(unitSystem: unitSystem)
                        }
                    }

                if hasEndDate {
                    Divider().padding(.leading)
                    DatePicker("To", selection: $localEndDate, displayedComponents: .date)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .onChange(of: localEndDate) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                vm.endDate = localEndDate
                                vm.refresh(unitSystem: unitSystem)
                            }
                        }
                }
            }

            // Route multiselect
            if !vm.namedRoutes.isEmpty {
                Divider()

                DisclosureGroup("Routes", isExpanded: $showRouteFilter) {
                    VStack(spacing: 0) {
                        routeToggle(
                            label: "Free Run",
                            isOn: $localIncludeFreeRuns
                        )

                        ForEach(vm.namedRoutes, id: \.id) { route in
                            Divider().padding(.leading)
                            routeToggle(
                                label: route.name,
                                isOn: routeBinding(for: route.id)
                            )
                        }

                        let hasFilter = !localSelectedRouteIDs.isEmpty || localIncludeFreeRuns
                        if hasFilter {
                            Divider().padding(.leading)
                            Button("Show All") {
                                localSelectedRouteIDs.removeAll()
                                localIncludeFreeRuns = false
                            }
                            .font(.caption)
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .onChange(of: localSelectedRouteIDs) {
                    scheduleRouteFilterApply()
                }
                .onChange(of: localIncludeFreeRuns) {
                    scheduleRouteFilterApply()
                }
            }

            Spacer().frame(height: 4)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func routeToggle(label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .padding(.vertical, 4)
    }

    private func routeBinding(for routeID: UUID) -> Binding<Bool> {
        Binding(
            get: { localSelectedRouteIDs.contains(routeID) },
            set: { isOn in
                if isOn {
                    localSelectedRouteIDs.insert(routeID)
                } else {
                    localSelectedRouteIDs.remove(routeID)
                }
            }
        )
    }

    private func scheduleRouteFilterApply() {
        routeDebounceTask?.cancel()
        routeDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel?.applyRouteFilter(
                    selectedRouteIDs: localSelectedRouteIDs,
                    includeFreeRuns: localIncludeFreeRuns,
                    unitSystem: unitSystem
                )
            }
        }
    }

    // MARK: - Axis Selection

    private func axisSection(vm: DataExplorerVM) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("X Axis")
                Spacer()
                Picker("X Axis", selection: Binding(
                    get: { vm.xAxis },
                    set: {
                        vm.xAxis = $0
                        vm.computeChartPoints(unitSystem: unitSystem)
                    }
                )) {
                    ForEach(DataExplorerAxis.allCases) { axis in
                        Text(axis.rawValue).tag(axis)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider().padding(.leading)

            HStack {
                Text("Y Axis")
                Spacer()
                Picker("Y Axis", selection: Binding(
                    get: { vm.yAxis },
                    set: {
                        vm.yAxis = $0
                        vm.computeChartPoints(unitSystem: unitSystem)
                    }
                )) {
                    ForEach(DataExplorerAxis.allCases) { axis in
                        Text(axis.rawValue).tag(axis)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Chart

    private func chartSection(vm: DataExplorerVM) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if vm.chartPoints.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Try adjusting your filters or selecting different axes.")
                )
                .frame(height: 280)
            } else if vm.xAxis.isDate {
                dateChart(vm: vm)
            } else {
                scatterChart(vm: vm)
            }

            trendLinePicker(vm: vm)
                .opacity(vm.chartPoints.isEmpty ? 0.4 : 1.0)
                .allowsHitTesting(!vm.chartPoints.isEmpty)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func trendLinePicker(vm: DataExplorerVM) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Trend Line")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if vm.xAxis.isWeather || vm.yAxis.isWeather {
                    Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
                        HStack(spacing: 2) {
                            Image(systemName: "apple.logo")
                            Text("Weather")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            Picker("Trend Line", selection: Binding(
                get: { vm.trendLineType },
                set: {
                    vm.trendLineType = $0
                    vm.computeTrendLine()
                }
            )) {
                ForEach(TrendLineType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func dateChart(vm: DataExplorerVM) -> some View {
        Chart {
            ForEach(vm.chartPoints) { point in
                LineMark(
                    x: .value(vm.xAxis.rawValue, point.date),
                    y: .value(vm.yAxis.rawValue, point.yValue),
                    series: .value("Series", "data")
                )
                .foregroundStyle(.blue.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value(vm.xAxis.rawValue, point.date),
                    y: .value(vm.yAxis.rawValue, point.yValue)
                )
                .foregroundStyle(.blue)
                .symbolSize(30)
            }

            ForEach(vm.trendLinePoints) { point in
                LineMark(
                    x: .value(vm.xAxis.rawValue, point.date),
                    y: .value(vm.yAxis.rawValue, point.yValue),
                    series: .value("Series", "trend")
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartForegroundStyleScale(["data": .blue, "trend": .red])
        .chartLegend(.hidden)
        .chartYAxisLabel(vm.yAxis.axisLabel(unitSystem: unitSystem))
        .frame(height: 280)
    }

    private func scatterChart(vm: DataExplorerVM) -> some View {
        Chart {
            ForEach(vm.chartPoints) { point in
                PointMark(
                    x: .value(vm.xAxis.rawValue, point.xValue),
                    y: .value(vm.yAxis.rawValue, point.yValue)
                )
                .foregroundStyle(.blue)
                .symbolSize(40)
            }

            ForEach(vm.trendLinePoints) { point in
                LineMark(
                    x: .value(vm.xAxis.rawValue, point.xValue),
                    y: .value(vm.yAxis.rawValue, point.yValue),
                    series: .value("Series", "trend")
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartLegend(.hidden)
        .chartXAxisLabel(vm.xAxis.axisLabel(unitSystem: unitSystem))
        .chartYAxisLabel(vm.yAxis.axisLabel(unitSystem: unitSystem))
        .frame(height: 280)
    }

    // MARK: - Export

    private func exportSection(vm: DataExplorerVM) -> some View {
        Button {
            if let url = vm.exportCSV(unitSystem: unitSystem) {
                exportURL = url
                showShareSheet = true
            }
        } label: {
            Label("Export CSV", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(vm.filteredRuns.isEmpty)
    }
}

// MARK: - Share Sheet

private struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
