//
//  CheckpointSavedToastView.swift
//  Run-Tracker
//

import SwiftUI

struct CheckpointSavedToastView: View {
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.orange)
            Text("\(label) saved")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
    }
}
