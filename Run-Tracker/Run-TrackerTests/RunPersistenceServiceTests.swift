//
//  RunPersistenceServiceTests.swift
//  Run-TrackerTests
//
//  Created by Jeremy McMinis on 3/8/26.
//

import XCTest
import SwiftData
@testable import Run_Tracker

@MainActor
final class RunPersistenceServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var service: RunPersistenceService!

    override func setUp() async throws {
        let schema = Schema([Run.self, Split.self, RoutePoint.self, NamedRoute.self, RouteCheckpoint.self, RunCheckpointResult.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        service = RunPersistenceService(modelContext: container.mainContext)
    }

    override func tearDown() async throws {
        container = nil
        service = nil
    }

    // MARK: - Run CRUD

    func testSaveAndFetchRun() throws {
        let run = Run(startDate: Date(), distanceMeters: 5000, durationSeconds: 1800)
        service.saveRun(run)

        let runs = service.fetchAllRuns()
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs.first?.distanceMeters, 5000)
    }

    func testDeleteRun() throws {
        let run = Run(startDate: Date(), distanceMeters: 3000, durationSeconds: 900)
        service.saveRun(run)
        XCTAssertEqual(service.fetchAllRuns().count, 1)

        service.deleteRun(run)
        XCTAssertEqual(service.fetchAllRuns().count, 0)
    }

    func testFetchMultipleRuns() throws {
        let run1 = Run(startDate: Date(timeIntervalSinceNow: -7200), distanceMeters: 3000, durationSeconds: 900)
        let run2 = Run(startDate: Date(), distanceMeters: 5000, durationSeconds: 1800)
        service.saveRun(run1)
        service.saveRun(run2)

        let runs = service.fetchAllRuns()
        XCTAssertEqual(runs.count, 2)
    }

    // MARK: - Split

    func testAddSplitToRun() throws {
        let run = Run(startDate: Date(), distanceMeters: 3000, durationSeconds: 900)
        service.saveRun(run)

        let split = Split(splitIndex: 1, distanceMeters: 1609.344, durationSeconds: 480, startDate: Date(), endDate: Date())
        service.addSplit(split, to: run)

        XCTAssertEqual(run.splits.count, 1)
        XCTAssertEqual(run.splits.first?.splitIndex, 1)
        XCTAssertEqual(split.run?.id, run.id)
    }

    // MARK: - RoutePoint

    func testAddRoutePointToRun() throws {
        let run = Run(startDate: Date(), distanceMeters: 1000, durationSeconds: 300)
        service.saveRun(run)

        let point = RoutePoint(latitude: 43.65, longitude: -79.38, altitude: 76.4, smoothedAltitude: 76.2, horizontalAccuracy: 5.0, speed: 3.0, distanceFromStart: 100)
        service.addRoutePoint(point, to: run)

        XCTAssertEqual(run.routePoints.count, 1)
        XCTAssertEqual(run.routePoints.first?.latitude, 43.65)
        XCTAssertEqual(point.run?.id, run.id)
    }

    // MARK: - NamedRoute CRUD

    func testSaveAndFetchNamedRoute() throws {
        let route = NamedRoute(name: "Morning Loop")
        service.saveNamedRoute(route)

        let routes = service.fetchAllNamedRoutes()
        XCTAssertEqual(routes.count, 1)
        XCTAssertEqual(routes.first?.name, "Morning Loop")
    }

    func testDeleteNamedRoute() throws {
        let route = NamedRoute(name: "Trail Run")
        service.saveNamedRoute(route)
        XCTAssertEqual(service.fetchAllNamedRoutes().count, 1)

        service.deleteNamedRoute(route)
        XCTAssertEqual(service.fetchAllNamedRoutes().count, 0)
    }

    func testAssignRouteToRun() throws {
        let run = Run(startDate: Date(), distanceMeters: 5000, durationSeconds: 1800)
        service.saveRun(run)
        let route = NamedRoute(name: "Park Loop")
        service.saveNamedRoute(route)

        service.assignRoute(route, to: run)
        XCTAssertEqual(run.namedRoute?.name, "Park Loop")
        XCTAssertEqual(route.runs.count, 1)
    }

    func testUnassignRouteFromRun() throws {
        let run = Run(startDate: Date(), distanceMeters: 5000, durationSeconds: 1800)
        service.saveRun(run)
        let route = NamedRoute(name: "Park Loop")
        service.saveNamedRoute(route)
        service.assignRoute(route, to: run)

        service.unassignRoute(from: run)
        XCTAssertNil(run.namedRoute)
    }

    // MARK: - Cascade delete

    func testDeletingRunCascadesSplitsAndRoutePoints() throws {
        let run = Run(startDate: Date(), distanceMeters: 5000, durationSeconds: 1800)
        service.saveRun(run)

        let split = Split(splitIndex: 1, distanceMeters: 1609.344, durationSeconds: 480, startDate: Date(), endDate: Date())
        service.addSplit(split, to: run)

        let point = RoutePoint(latitude: 43.65, longitude: -79.38, altitude: 76.4, smoothedAltitude: 76.2, horizontalAccuracy: 5.0, speed: 3.0, distanceFromStart: 100)
        service.addRoutePoint(point, to: run)

        service.deleteRun(run)

        let context = container.mainContext
        let splitCount = (try? context.fetch(FetchDescriptor<Split>()))?.count ?? 0
        let pointCount = (try? context.fetch(FetchDescriptor<RoutePoint>()))?.count ?? 0
        XCTAssertEqual(splitCount, 0)
        XCTAssertEqual(pointCount, 0)
    }

    func testSplitIsCoolDownRoundTrips() throws {
        let run = Run(startDate: Date(), distanceMeters: 5000, durationSeconds: 1800)
        service.saveRun(run)

        let split = Split(
            splitIndex: 1,
            distanceMeters: 1609.344,
            durationSeconds: 480,
            startDate: Date(),
            endDate: Date(),
            isCoolDown: true
        )
        service.addSplit(split, to: run)

        let context = container.mainContext
        let fetched = try context.fetch(FetchDescriptor<Split>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertTrue(fetched.first!.isCoolDown)
    }

    func testSplitIsCoolDownDefaultsFalse() throws {
        let run = Run(startDate: Date(), distanceMeters: 5000, durationSeconds: 1800)
        service.saveRun(run)

        let split = Split(
            splitIndex: 1,
            distanceMeters: 1609.344,
            durationSeconds: 480,
            startDate: Date(),
            endDate: Date()
        )
        service.addSplit(split, to: run)

        let context = container.mainContext
        let fetched = try context.fetch(FetchDescriptor<Split>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertFalse(fetched.first!.isCoolDown)
    }

    // MARK: - Checkpoint Models

    func testRouteCheckpointRoundTrip() throws {
        let route = NamedRoute(name: "Checkpoint Route")
        service.saveNamedRoute(route)

        let checkpoint = RouteCheckpoint(
            latitude: 37.7749,
            longitude: -122.4194,
            label: "Checkpoint 1",
            order: 0,
            namedRoute: route
        )
        let context = container.mainContext
        context.insert(checkpoint)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RouteCheckpoint>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.label, "Checkpoint 1")
        XCTAssertEqual(fetched.first?.namedRoute?.name, "Checkpoint Route")
        XCTAssertEqual(route.checkpoints.count, 1)
    }

    func testRunCheckpointResultRoundTrip() throws {
        let route = NamedRoute(name: "Test Route")
        service.saveNamedRoute(route)

        let checkpoint = RouteCheckpoint(
            latitude: 37.0,
            longitude: -122.0,
            label: "CP1",
            order: 0,
            namedRoute: route
        )

        let run = Run(startDate: Date(), distanceMeters: 5000, durationSeconds: 1800)
        service.saveRun(run)

        let result = RunCheckpointResult(
            elapsedSeconds: 300,
            cumulativeDistanceMeters: 1000,
            checkpoint: checkpoint,
            run: run
        )

        let context = container.mainContext
        context.insert(checkpoint)
        context.insert(result)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RunCheckpointResult>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.elapsedSeconds, 300)
        XCTAssertEqual(fetched.first?.cumulativeDistanceMeters, 1000)
        XCTAssertEqual(fetched.first?.checkpoint?.label, "CP1")
        XCTAssertEqual(fetched.first?.run?.id, run.id)
        XCTAssertEqual(run.checkpointResults.count, 1)
    }

    func testDeletingNamedRouteNullifiesRunRelationship() throws {
        let run = Run(startDate: Date(), distanceMeters: 5000, durationSeconds: 1800)
        service.saveRun(run)
        let route = NamedRoute(name: "Park Loop")
        service.saveNamedRoute(route)
        service.assignRoute(route, to: run)

        service.deleteNamedRoute(route)

        XCTAssertNil(run.namedRoute)
        XCTAssertEqual(service.fetchAllRuns().count, 1)
    }
}
