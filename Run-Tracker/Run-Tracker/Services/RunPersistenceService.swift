//
//  RunPersistenceService.swift
//  Run-Tracker
//
//  Created by Jeremy McMinis on 3/8/26.
//

import Foundation
import SwiftData

struct RunPersistenceService {
    let modelContext: ModelContext

    // MARK: - Run CRUD

    func saveRun(_ run: Run) {
        modelContext.insert(run)
        try? modelContext.save()
    }

    func deleteRun(_ run: Run) {
        modelContext.delete(run)
        try? modelContext.save()
    }

    func fetchAllRuns() -> [Run] {
        let descriptor = FetchDescriptor<Run>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchAllRunsSorted() -> [Run] {
        var descriptor = FetchDescriptor<Run>()
        descriptor.sortBy = [SortDescriptor(\Run.startDate, order: .reverse)]
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Split

    func addSplit(_ split: Split, to run: Run) {
        split.run = run
        run.splits.append(split)
        try? modelContext.save()
    }

    // MARK: - RoutePoint

    func addRoutePoint(_ point: RoutePoint, to run: Run) {
        point.run = run
        run.routePoints.append(point)
        try? modelContext.save()
    }

    // MARK: - NamedRoute CRUD

    func saveNamedRoute(_ route: NamedRoute) {
        modelContext.insert(route)
        try? modelContext.save()
    }

    func deleteNamedRoute(_ route: NamedRoute) {
        modelContext.delete(route)
        try? modelContext.save()
    }

    func fetchAllNamedRoutes() -> [NamedRoute] {
        let descriptor = FetchDescriptor<NamedRoute>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func assignRoute(_ route: NamedRoute, to run: Run) {
        run.namedRoute = route
        if !route.runs.contains(where: { $0.id == run.id }) {
            route.runs.append(run)
        }
        try? modelContext.save()
    }

    func unassignRoute(from run: Run) {
        run.namedRoute = nil
        try? modelContext.save()
    }

}
