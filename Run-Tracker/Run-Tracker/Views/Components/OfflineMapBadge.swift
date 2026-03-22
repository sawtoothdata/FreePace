//
//  OfflineMapBadge.swift
//  Run-Tracker
//

import SwiftUI
import Network

struct OfflineMapBadge: View {
    @State private var isOffline = false
    private let monitor = NWPathMonitor()

    var body: some View {
        Group {
            if isOffline {
                HStack(spacing: 4) {
                    Image(systemName: "airplane")
                        .font(.caption2)
                    Text("Offline")
                        .font(.caption2.weight(.semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .onAppear {
            startMonitoring()
        }
        .onDisappear {
            monitor.cancel()
        }
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { path in
            Task { @MainActor in
                isOffline = path.status != .satisfied
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
    }
}
