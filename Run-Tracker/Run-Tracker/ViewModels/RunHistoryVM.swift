//
//  RunHistoryVM.swift
//  Run-Tracker
//

import Foundation
import SwiftData

enum RunSortField: String, CaseIterable {
    case date = "Date"
    case distance = "Distance"
    case duration = "Duration"
    case pace = "Pace"
}

@Observable
final class RunHistoryVM {
    private let modelContext: ModelContext

    // Sort
    var sortField: RunSortField = .date
    var sortAscending: Bool = false

    // Filters
    var filterStartDate: Date?
    var filterEndDate: Date?
    var filterMinDistanceMeters: Double?
    var filterNamedRoute: NamedRoute?

    // Results
    private(set) var runs: [Run] = []
    private(set) var namedRoutes: [NamedRoute] = []

    var hasActiveFilters: Bool {
        filterStartDate != nil || filterEndDate != nil ||
        filterMinDistanceMeters != nil || filterNamedRoute != nil
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchRuns()
        fetchNamedRoutes()
    }

    // MARK: - Fetching

    func fetchRuns() {
        var descriptor = FetchDescriptor<Run>()

        // Sorting
        switch sortField {
        case .date:
            descriptor.sortBy = [SortDescriptor(\Run.startDate, order: sortAscending ? .forward : .reverse)]
        case .distance:
            descriptor.sortBy = [SortDescriptor(\Run.distanceMeters, order: sortAscending ? .forward : .reverse)]
        case .duration:
            descriptor.sortBy = [SortDescriptor(\Run.durationSeconds, order: sortAscending ? .forward : .reverse)]
        case .pace:
            // Pace = durationSeconds / distanceMeters (seconds per meter)
            // We can't sort by computed values in SwiftData, so fetch all and sort in memory
            descriptor.sortBy = [SortDescriptor(\Run.startDate, order: .reverse)]
        }

        var allRuns = (try? modelContext.fetch(descriptor)) ?? []

        // Apply filters in memory
        if let startDate = filterStartDate {
            allRuns = allRuns.filter { $0.startDate >= startDate }
        }
        if let endDate = filterEndDate {
            allRuns = allRuns.filter { $0.startDate <= endDate }
        }
        if let minDistance = filterMinDistanceMeters {
            allRuns = allRuns.filter { $0.distanceMeters >= minDistance }
        }
        if let route = filterNamedRoute {
            allRuns = allRuns.filter { $0.namedRoute?.id == route.id }
        }

        // Sort by pace in memory if needed
        if sortField == .pace {
            allRuns.sort { a, b in
                let paceA = a.distanceMeters > 0 ? a.durationSeconds / a.distanceMeters : Double.infinity
                let paceB = b.distanceMeters > 0 ? b.durationSeconds / b.distanceMeters : Double.infinity
                return sortAscending ? paceA < paceB : paceA > paceB
            }
        }

        runs = allRuns
    }

    func fetchNamedRoutes() {
        let descriptor = FetchDescriptor<NamedRoute>(sortBy: [SortDescriptor(\NamedRoute.name)])
        namedRoutes = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Actions

    func deleteRun(_ run: Run) {
        let service = RunPersistenceService(modelContext: modelContext)
        service.deleteRun(run)
        fetchRuns()
    }

    func resetFilters() {
        filterStartDate = nil
        filterEndDate = nil
        filterMinDistanceMeters = nil
        filterNamedRoute = nil
        sortField = .date
        sortAscending = false
        fetchRuns()
    }

    func applyFilters() {
        fetchRuns()
    }
}
