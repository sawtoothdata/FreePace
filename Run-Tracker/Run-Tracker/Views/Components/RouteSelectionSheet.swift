//
//  RouteSelectionSheet.swift
//  Run-Tracker
//

import SwiftUI
import SwiftData

struct RouteSelectionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("coachModeDefault") private var coachModeDefault: Bool = true

    let onFreeRun: () -> Void
    let onRouteSelected: (NamedRoute, Bool) -> Void // (route, coachModeEnabled)

    @State private var routes: [NamedRoute] = []
    @State private var selectedRoute: NamedRoute?
    @State private var coachModeEnabled: Bool = true

    var body: some View {
        NavigationStack {
            List {
                // Free Run option
                Section {
                    Button {
                        dismiss()
                        onFreeRun()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.run")
                                .font(.title2)
                                .foregroundStyle(.green)
                                .frame(width: 36)
                            VStack(alignment: .leading) {
                                Text("Free Run")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Run without a route")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Named routes
                if !routes.isEmpty {
                    Section("Your Routes") {
                        ForEach(routes, id: \.id) { route in
                            Button {
                                dismiss()
                                onRouteSelected(route, coachModeEnabled)
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
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    // Coach mode toggle
                    Section {
                        Toggle(isOn: $coachModeEnabled) {
                            HStack(spacing: 8) {
                                Image(systemName: "figure.run.circle")
                                    .foregroundStyle(.green)
                                VStack(alignment: .leading) {
                                    Text("Coach Mode")
                                        .font(.subheadline.weight(.medium))
                                    Text("Audio comparison to past runs")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.green)
                    }
                }
            }
            .navigationTitle("Choose Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadRoutes()
                coachModeEnabled = coachModeDefault
            }
            .onChange(of: coachModeEnabled) { _, newValue in
                coachModeDefault = newValue
            }
        }
        .presentationDetents([.medium])
    }

    private func loadRoutes() {
        let service = RunPersistenceService(modelContext: modelContext)
        routes = service.fetchAllNamedRoutes()
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
