//
//  RunHistoryVMTests.swift
//  Run-TrackerTests
//

import XCTest
import SwiftData
@testable import Run_Tracker

@MainActor
final class RunHistoryVMTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([Run.self, Split.self, RoutePoint.self, NamedRoute.self, RouteCheckpoint.self, RunCheckpointResult.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - Helpers

    private func insertRun(
        startDate: Date = Date(),
        distanceMeters: Double = 5000,
        durationSeconds: Double = 1800,
        namedRoute: NamedRoute? = nil
    ) -> Run {
        let run = Run(
            startDate: startDate,
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds,
            namedRoute: namedRoute
        )
        context.insert(run)
        try? context.save()
        return run
    }

    // MARK: - Basic Fetch

    func testFetchRuns_Empty() {
        let vm = RunHistoryVM(modelContext: context)
        XCTAssertTrue(vm.runs.isEmpty)
    }

    func testFetchRuns_ReturnsInsertedRuns() {
        _ = insertRun()
        _ = insertRun(distanceMeters: 10000)

        let vm = RunHistoryVM(modelContext: context)
        XCTAssertEqual(vm.runs.count, 2)
    }

    // MARK: - Sort by Date

    func testSortByDate_Descending() {
        let older = insertRun(startDate: Date(timeIntervalSinceNow: -7200))
        let newer = insertRun(startDate: Date())

        let vm = RunHistoryVM(modelContext: context)
        vm.sortField = .date
        vm.sortAscending = false
        vm.fetchRuns()

        XCTAssertEqual(vm.runs.first?.id, newer.id)
        XCTAssertEqual(vm.runs.last?.id, older.id)
    }

    func testSortByDate_Ascending() {
        let older = insertRun(startDate: Date(timeIntervalSinceNow: -7200))
        let newer = insertRun(startDate: Date())

        let vm = RunHistoryVM(modelContext: context)
        vm.sortField = .date
        vm.sortAscending = true
        vm.fetchRuns()

        XCTAssertEqual(vm.runs.first?.id, older.id)
        XCTAssertEqual(vm.runs.last?.id, newer.id)
    }

    // MARK: - Sort by Distance

    func testSortByDistance_Descending() {
        let short = insertRun(distanceMeters: 3000)
        let long = insertRun(distanceMeters: 10000)

        let vm = RunHistoryVM(modelContext: context)
        vm.sortField = .distance
        vm.sortAscending = false
        vm.fetchRuns()

        XCTAssertEqual(vm.runs.first?.id, long.id)
        XCTAssertEqual(vm.runs.last?.id, short.id)
    }

    // MARK: - Sort by Duration

    func testSortByDuration_Ascending() {
        let fast = insertRun(durationSeconds: 900)
        let slow = insertRun(durationSeconds: 3600)

        let vm = RunHistoryVM(modelContext: context)
        vm.sortField = .duration
        vm.sortAscending = true
        vm.fetchRuns()

        XCTAssertEqual(vm.runs.first?.id, fast.id)
        XCTAssertEqual(vm.runs.last?.id, slow.id)
    }

    // MARK: - Sort by Pace

    func testSortByPace_Ascending() {
        // Fast pace: 5000m in 1200s = 0.24 s/m
        let fast = insertRun(distanceMeters: 5000, durationSeconds: 1200)
        // Slow pace: 5000m in 2400s = 0.48 s/m
        let slow = insertRun(distanceMeters: 5000, durationSeconds: 2400)

        let vm = RunHistoryVM(modelContext: context)
        vm.sortField = .pace
        vm.sortAscending = true
        vm.fetchRuns()

        XCTAssertEqual(vm.runs.first?.id, fast.id)
        XCTAssertEqual(vm.runs.last?.id, slow.id)
    }

    // MARK: - Filter by Date Range

    func testFilterByDateRange() {
        let now = Date()
        let yesterday = insertRun(startDate: now.addingTimeInterval(-86400))
        _ = insertRun(startDate: now.addingTimeInterval(-172800)) // 2 days ago
        let today = insertRun(startDate: now)

        let vm = RunHistoryVM(modelContext: context)
        vm.filterStartDate = now.addingTimeInterval(-90000) // ~25 hours ago
        vm.fetchRuns()

        XCTAssertEqual(vm.runs.count, 2)
        let ids = vm.runs.map(\.id)
        XCTAssertTrue(ids.contains(yesterday.id))
        XCTAssertTrue(ids.contains(today.id))
    }

    func testFilterByEndDate() {
        let now = Date()
        _ = insertRun(startDate: now) // today — excluded
        let old = insertRun(startDate: now.addingTimeInterval(-172800))

        let vm = RunHistoryVM(modelContext: context)
        vm.filterEndDate = now.addingTimeInterval(-86400) // 1 day ago
        vm.fetchRuns()

        XCTAssertEqual(vm.runs.count, 1)
        XCTAssertEqual(vm.runs.first?.id, old.id)
    }

    // MARK: - Filter by Min Distance

    func testFilterByMinDistance() {
        _ = insertRun(distanceMeters: 2000) // too short
        let long = insertRun(distanceMeters: 8000)

        let vm = RunHistoryVM(modelContext: context)
        vm.filterMinDistanceMeters = 5000
        vm.fetchRuns()

        XCTAssertEqual(vm.runs.count, 1)
        XCTAssertEqual(vm.runs.first?.id, long.id)
    }

    // MARK: - Filter by Named Route

    func testFilterByNamedRoute() {
        let route = NamedRoute(name: "Park Loop")
        context.insert(route)
        try? context.save()

        let withRoute = insertRun(namedRoute: route)
        _ = insertRun() // no route

        let vm = RunHistoryVM(modelContext: context)
        vm.filterNamedRoute = route
        vm.fetchRuns()

        XCTAssertEqual(vm.runs.count, 1)
        XCTAssertEqual(vm.runs.first?.id, withRoute.id)
    }

    // MARK: - Delete

    func testDeleteRun() {
        let run = insertRun()

        let vm = RunHistoryVM(modelContext: context)
        XCTAssertEqual(vm.runs.count, 1)

        vm.deleteRun(run)
        XCTAssertEqual(vm.runs.count, 0)
    }

    // MARK: - Reset Filters

    func testResetFilters() {
        _ = insertRun(distanceMeters: 1000)
        _ = insertRun(distanceMeters: 10000)

        let vm = RunHistoryVM(modelContext: context)
        vm.filterMinDistanceMeters = 5000
        vm.fetchRuns()
        XCTAssertEqual(vm.runs.count, 1)

        vm.resetFilters()
        XCTAssertEqual(vm.runs.count, 2)
        XCTAssertNil(vm.filterMinDistanceMeters)
        XCTAssertNil(vm.filterStartDate)
        XCTAssertNil(vm.filterEndDate)
        XCTAssertNil(vm.filterNamedRoute)
    }

    // MARK: - Has Active Filters

    func testHasActiveFilters_False() {
        let vm = RunHistoryVM(modelContext: context)
        XCTAssertFalse(vm.hasActiveFilters)
    }

    func testHasActiveFilters_True() {
        let vm = RunHistoryVM(modelContext: context)
        vm.filterMinDistanceMeters = 5000
        XCTAssertTrue(vm.hasActiveFilters)
    }

    // MARK: - Named Routes Fetch

    func testFetchNamedRoutes() {
        let route1 = NamedRoute(name: "Alpha Route")
        let route2 = NamedRoute(name: "Beta Route")
        context.insert(route1)
        context.insert(route2)
        try? context.save()

        let vm = RunHistoryVM(modelContext: context)
        XCTAssertEqual(vm.namedRoutes.count, 2)
        XCTAssertEqual(vm.namedRoutes.first?.name, "Alpha Route")
    }
}
