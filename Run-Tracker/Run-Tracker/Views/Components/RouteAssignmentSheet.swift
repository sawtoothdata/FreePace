//
//  RouteAssignmentSheet.swift
//  Run-Tracker
//

import SwiftUI
import SwiftData

struct RouteAssignmentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let run: Run
    var freeRunCheckpoints: [RouteCheckpoint] = []
    var onAssigned: (() -> Void)?

    @State private var newRouteName: String = ""
    @State private var existingRoutes: [NamedRoute] = []
    @State private var useSingleLoop: Bool = true
    @State private var detectedLoopDistance: Double?

    var body: some View {
        NavigationStack {
            List {
                Section("Create New Route") {
                    HStack {
                        TextField("Route name", text: $newRouteName)
                            .textFieldStyle(.plain)
                            .submitLabel(.done)

                        Button("Save") {
                            createAndAssign()
                        }
                        .disabled(newRouteName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                    }

                    if detectedLoopDistance != nil {
                        Toggle("Save as single loop", isOn: $useSingleLoop)
                        Text("This run has multiple laps. Enable to store just one clean loop for the route.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !existingRoutes.isEmpty {
                    Section("Existing Routes") {
                        ForEach(existingRoutes, id: \.id) { route in
                            Button {
                                assignExisting(route)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(route.name)
                                            .foregroundStyle(.primary)
                                        Text("\(route.runs.count) \(route.runs.count == 1 ? "run" : "runs")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if run.namedRoute?.id == route.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                if run.namedRoute != nil {
                    Section {
                        Button("Remove Route Assignment", role: .destructive) {
                            unassignRoute()
                        }
                    }
                }
            }
            .navigationTitle("Name Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadRoutes()
                if let currentName = run.namedRoute?.name {
                    newRouteName = currentName
                }
                detectedLoopDistance = BearingUtils.detectLoopEndDistance(
                    routePoints: run.routePoints
                )
            }
        }
    }

    private func loadRoutes() {
        let service = RunPersistenceService(modelContext: modelContext)
        existingRoutes = service.fetchAllNamedRoutes()
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func createAndAssign() {
        let trimmed = newRouteName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let name = String(trimmed.prefix(50))

        let service = RunPersistenceService(modelContext: modelContext)
        let route = NamedRoute(
            name: name,
            singleLapMaxDistance: useSingleLoop ? detectedLoopDistance : nil
        )
        service.saveNamedRoute(route)
        service.assignRoute(route, to: run)
        attachFreeRunCheckpoints(to: route)
        // Auto-cache map tiles for this route
        MapTileCacheService.shared.cacheRoute(route)
        onAssigned?()
        dismiss()
    }

    private func assignExisting(_ route: NamedRoute) {
        let service = RunPersistenceService(modelContext: modelContext)
        service.assignRoute(route, to: run)
        attachFreeRunCheckpoints(to: route)
        // Auto-cache map tiles for this route
        MapTileCacheService.shared.cacheRoute(route)
        onAssigned?()
        dismiss()
    }

    private func attachFreeRunCheckpoints(to route: NamedRoute) {
        for checkpoint in freeRunCheckpoints {
            checkpoint.namedRoute = route
            checkpoint.order = route.checkpoints.count
            route.checkpoints.append(checkpoint)
        }
    }

    private func unassignRoute() {
        let service = RunPersistenceService(modelContext: modelContext)
        service.unassignRoute(from: run)
        onAssigned?()
        dismiss()
    }
}
