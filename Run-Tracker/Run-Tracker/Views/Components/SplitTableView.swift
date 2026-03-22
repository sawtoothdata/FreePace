//
//  SplitTableView.swift
//  Run-Tracker
//

import SwiftUI

struct SplitTableView: View {
    let splits: [SplitDisplayData]
    let fastestSplitIndex: Int?
    let slowestSplitIndex: Int?
    let unitSystem: UnitSystem
    var splitDistance: SplitDistance = .full

    var body: some View {
        if splits.isEmpty {
            Text("No splits recorded")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SPLITS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(splitDistance.splitLabel(for: unitSystem))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                // Card rows
                ForEach(splits) { split in
                    splitCardRow(split)
                }
            }
        }
    }

    // MARK: - Card Row

    private func splitCardRow(_ split: SplitDisplayData) -> some View {
        let isFastest = split.index == fastestSplitIndex
        let isSlowest = split.index == slowestSplitIndex

        return HStack(spacing: 0) {
            // Accent bar
            Rectangle()
                .fill(accentColor(isFastest: isFastest, isSlowest: isSlowest))
                .frame(width: 3)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                // Top row: split label + cool-down icon
                HStack(spacing: 6) {
                    Text(splitLabel(for: split))
                        .font(.headline)
                    if split.isCoolDown {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // Pace row
                HStack(spacing: 4) {
                    Text(split.paceSecondsPerMeter.asPace(unit: unitSystem))
                        .font(.system(.title2, design: .monospaced))
                        .italic(split.isPartial)
                    if split.isPartial {
                        Text("(partial)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Secondary stats row
                HStack(spacing: 12) {
                    Text("\u{2191} " + split.elevationGainMeters.asElevation(unit: unitSystem))
                    Text("\u{2193} " + split.elevationLossMeters.asElevation(unit: unitSystem))
                    if let cadence = split.averageCadence {
                        Text("\u{25C6} \(Int(cadence)) spm")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Footer row: distance and duration
                HStack {
                    Spacer()
                    Text("\(split.distanceMeters.asDistance(unit: unitSystem)) \u{00B7} \(split.durationSeconds.asCompactDuration())")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(minHeight: 72)
        .background(split.isCoolDown ? Color(.systemFill) : Color.clear)
    }

    // MARK: - Helpers

    private func splitLabel(for split: SplitDisplayData) -> String {
        let converted = split.cumulativeDistanceMeters / unitSystem.metersPerDistanceUnit
        return String(format: "%.2f %@", converted, unitSystem.distanceUnit)
    }

    private func accentColor(isFastest: Bool, isSlowest: Bool) -> Color {
        if isFastest { return .green }
        if isSlowest { return .red }
        return .clear
    }
}
