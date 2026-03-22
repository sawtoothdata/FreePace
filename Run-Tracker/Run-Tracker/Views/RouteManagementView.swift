//
//  RouteManagementView.swift
//  Run-Tracker
//

import SwiftUI
import SwiftData

struct RouteManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NamedRoute.name) private var routes: [NamedRoute]
    @State private var routeToDelete: NamedRoute?

    var body: some View {
        List {
            if routes.isEmpty {
                ContentUnavailableView(
                    "No Routes",
                    systemImage: "map",
                    description: Text("Named routes will appear here after you assign a name to a run.")
                )
            } else {
                ForEach(routes, id: \.id) { route in
                    NavigationLink(destination: RouteDetailView(route: route)) {
                        routeRow(route)
                    }
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        routeToDelete = routes[index]
                    }
                }
            }
        }
        .alert("Delete Route?", isPresented: Binding(
            get: { routeToDelete != nil },
            set: { if !$0 { routeToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let route = routeToDelete {
                    deleteRoute(route)
                }
                routeToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                routeToDelete = nil
            }
        } message: {
            if let route = routeToDelete {
                Text("Delete \"\(route.name)\"? This will remove the route but keep all associated runs.")
            }
        }
    }

    private func routeRow(_ route: NamedRoute) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(route.name)
                    .font(.headline)
                HStack(spacing: 12) {
                    Label("\(route.runs.count) \(route.runs.count == 1 ? "run" : "runs")", systemImage: "figure.run")
                    let pinCount = checkpointCount(for: route)
                    Label("\(pinCount) \(pinCount == 1 ? "pin" : "pins")", systemImage: "mappin")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let coords = routeCoordinates(for: route), coords.count >= 2 {
                RouteSnapshotView(coordinates: coords)
            }
        }
        .padding(.vertical, 2)
    }

    private func routeCoordinates(for route: NamedRoute) -> [(Double, Double)]? {
        // Use the most recent run that has route points
        guard let run = route.runs
            .filter({ !$0.routePoints.isEmpty })
            .sorted(by: { $0.startDate > $1.startDate })
            .first else { return nil }
        let points = run.routePoints.sorted { $0.timestamp < $1.timestamp }
        return points.map { ($0.latitude, $0.longitude) }
    }

    private func checkpointCount(for route: NamedRoute) -> Int {
        let routeID = route.id
        let descriptor = FetchDescriptor<RouteCheckpoint>(
            predicate: #Predicate { $0.namedRoute?.id == routeID }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    private func deleteRoute(_ route: NamedRoute) {
        // Unassign runs from this route before deleting
        for run in route.runs {
            run.namedRoute = nil
        }
        modelContext.delete(route)
        try? modelContext.save()
    }
}
