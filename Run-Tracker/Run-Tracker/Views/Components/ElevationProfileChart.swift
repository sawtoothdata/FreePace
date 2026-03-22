//
//  ElevationProfileChart.swift
//  Run-Tracker
//

import SwiftUI
import Charts

/// Compute the Y-axis domain for the elevation chart
func elevationChartDomain(points: [ElevationProfilePoint], unitSystem: UnitSystem) -> ClosedRange<Double> {
    guard !points.isEmpty else { return -5...5 }

    let conversionFactor: Double = unitSystem == .imperial ? 3.28084 : 1.0
    let elevations = points.map { $0.elevationMeters * conversionFactor }

    let minEle = elevations.min()!
    let maxEle = elevations.max()!

    if minEle == maxEle {
        return (minEle - 5)...(maxEle + 5)
    }

    let padding = max((maxEle - minEle) * 0.15, 1.0)
    return (minEle - padding)...(maxEle + padding)
}

struct ElevationProfileChart: View {
    let dataPoints: [ElevationProfilePoint]
    let unitSystem: UnitSystem
    var totalDistanceMeters: Double? = nil

    /// Points per distance unit for chart width calculation
    private let pointsPerUnit: CGFloat = 120

    var body: some View {
        if dataPoints.isEmpty {
            ContentUnavailableView("No Elevation Data", systemImage: "mountain.2",
                                   description: Text("No route data available."))
                .frame(height: 200)
        } else {
            let yDomain = elevationChartDomain(points: dataPoints, unitSystem: unitSystem)
            let maxDistanceConverted = (totalDistanceMeters ?? dataPoints.last?.distanceMeters ?? 0)
                .toDistanceValue(unit: unitSystem)

            GeometryReader { geometry in
                let distanceUnits = maxDistanceConverted
                let calculatedWidth = distanceUnits * pointsPerUnit
                let chartWidth = max(geometry.size.width, calculatedWidth)

                ScrollView(.horizontal, showsIndicators: true) {
                    Chart(dataPoints) { point in
                        let distance = point.distanceMeters.toDistanceValue(unit: unitSystem)
                        let elevation = point.elevationMeters.toElevationValue(unit: unitSystem)

                        AreaMark(
                            x: .value("Distance", distance),
                            yStart: .value("Base", yDomain.lowerBound),
                            yEnd: .value("Elevation", elevation)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green.opacity(0.6), .brown.opacity(0.4)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )

                        LineMark(
                            x: .value("Distance", distance),
                            y: .value("Elevation", elevation)
                        )
                        .foregroundStyle(.brown)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .chartXAxisLabel(unitSystem.distanceUnit)
                    .chartYAxisLabel(unitSystem.elevationUnit)
                    .chartYScale(domain: yDomain)
                    .chartXScale(domain: 0...max(maxDistanceConverted, 0.01))
                    .frame(width: chartWidth, height: 200)
                }
            }
            .frame(height: 200)
        }
    }
}
