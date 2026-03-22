//
//  CheckpointToastView.swift
//  Run-Tracker
//

import SwiftUI

struct CheckpointToastView: View {
    let label: String
    let elapsedSeconds: Double
    let delta: Double? // negative = ahead, positive = behind; nil = no reference

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.orange)

                Text(label)
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            Text(elapsedSeconds.asCompactDuration())
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(.white)

            if let delta = delta {
                deltaView(delta: delta)
            } else {
                Text("No reference")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
    }

    private func deltaView(delta: Double) -> some View {
        let isAhead = delta <= 0
        let absDelta = abs(delta)
        let minutes = Int(absDelta) / 60
        let seconds = Int(absDelta) % 60
        let sign = isAhead ? "-" : "+"
        let text = String(format: "%@%d:%02d", sign, minutes, seconds)

        return Text(text)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(isAhead ? .green : .red))
    }
}
