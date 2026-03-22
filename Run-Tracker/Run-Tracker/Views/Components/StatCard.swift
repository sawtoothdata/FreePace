//
//  StatCard.swift
//  Run-Tracker
//

import SwiftUI

struct StatCard: View {
    let value: String
    let unit: String
    var valueFont: Font = .system(size: 24, weight: .bold, design: .monospaced)
    var unitFont: Font = .system(size: 14, weight: .medium, design: .default)

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(valueFont)
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(unit)
                .font(unitFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack {
        StatCard(value: "5.23", unit: "mi")
        StatCard(
            value: "02:34:17",
            unit: "time",
            valueFont: .system(size: 48, weight: .bold, design: .monospaced)
        )
    }
}
