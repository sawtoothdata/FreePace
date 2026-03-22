//
//  SplitToastView.swift
//  Run-Tracker
//

import SwiftUI

struct SplitToastView: View {
    let splitIndex: Int
    let durationSeconds: Double
    let splitDistance: SplitDistance
    let unitSystem: UnitSystem
    var coachDelta: Double? = nil // negative = ahead, positive = behind

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                Text(unitLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))

                Text(durationSeconds.asCompactDuration())
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            if let delta = coachDelta {
                coachDeltaView(delta: delta)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
    }

    private var unitLabel: String {
        let label = splitDistance.splitLabel(for: unitSystem)
        return "\(label) \(splitIndex)"
    }

    private func coachDeltaView(delta: Double) -> some View {
        let isAhead = delta <= 0
        let absDelta = abs(delta)
        let minutes = Int(absDelta) / 60
        let seconds = Int(absDelta) % 60
        let sign = isAhead ? "-" : "+"
        let text = String(format: "%@%d:%02d", sign, minutes, seconds)

        return Text(text)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(isAhead ? .green : .red)
    }
}

#Preview {
    VStack(spacing: 20) {
        SplitToastView(splitIndex: 3, durationSeconds: 462, splitDistance: .full, unitSystem: .imperial)
        SplitToastView(splitIndex: 2, durationSeconds: 448, splitDistance: .full, unitSystem: .imperial, coachDelta: -12)
        SplitToastView(splitIndex: 1, durationSeconds: 510, splitDistance: .full, unitSystem: .imperial, coachDelta: 23)
    }
}
