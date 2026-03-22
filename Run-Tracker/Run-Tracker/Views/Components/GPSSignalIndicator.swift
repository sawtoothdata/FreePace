//
//  GPSSignalIndicator.swift
//  Run-Tracker
//

import SwiftUI

struct GPSSignalIndicator: View {
    let horizontalAccuracy: Double

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < barCount ? barColor : Color.gray.opacity(0.3))
                    .frame(width: 5, height: CGFloat(6 + index * 4))
            }
        }
    }

    var barCount: Int {
        if horizontalAccuracy < 0 { return 0 }
        if horizontalAccuracy <= 10 { return 3 }
        if horizontalAccuracy <= 30 { return 2 }
        if horizontalAccuracy <= 50 { return 1 }
        return 0
    }

    private var barColor: Color {
        switch barCount {
        case 3: return .green
        case 2: return .yellow
        case 1: return .orange
        default: return .red
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GPSSignalIndicator(horizontalAccuracy: 5)
        GPSSignalIndicator(horizontalAccuracy: 20)
        GPSSignalIndicator(horizontalAccuracy: 40)
        GPSSignalIndicator(horizontalAccuracy: 100)
    }
}
