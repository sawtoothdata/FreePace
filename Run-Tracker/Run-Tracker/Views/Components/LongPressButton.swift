//
//  LongPressButton.swift
//  Run-Tracker
//

import SwiftUI

struct LongPressButton: View {
    let title: String
    var color: Color = .red
    var size: CGFloat = 70
    var holdDuration: TimeInterval = 1.5
    var onComplete: () -> Void

    @State private var isPressed = false
    @State private var progress: CGFloat = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: size, height: size)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.05), value: progress)

            // Inner circle
            Circle()
                .fill(color)
                .frame(width: size - 16, height: size - 16)
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isPressed)

            // Label
            Text(title)
                .font(.system(size: size * 0.18, weight: .bold))
                .foregroundStyle(.white)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        startHoldTimer()
                    }
                }
                .onEnded { _ in
                    cancelHold()
                }
        )
    }

    private func startHoldTimer() {
        progress = 0
        let interval: TimeInterval = 0.03
        let increment = CGFloat(interval / holdDuration)

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { t in
            progress += increment
            if progress >= 1.0 {
                t.invalidate()
                timer = nil
                progress = 1.0
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                onComplete()
                // Reset after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isPressed = false
                    progress = 0
                }
            }
        }
    }

    private func cancelHold() {
        timer?.invalidate()
        timer = nil
        isPressed = false
        progress = 0
    }
}

#Preview {
    LongPressButton(title: "STOP", color: .red) {
        print("Stop triggered")
    }
}
