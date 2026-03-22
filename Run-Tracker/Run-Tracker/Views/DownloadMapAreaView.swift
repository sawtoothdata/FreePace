//
//  DownloadMapAreaView.swift
//  Run-Tracker
//

import SwiftUI
import MapKit

struct DownloadMapAreaView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var visibleRegion: MKCoordinateRegion?

    private let cacheService = MapTileCacheService.shared

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition)
                    .mapStyle(.standard)
                    .onMapCameraChange { context in
                        visibleRegion = context.region
                    }

                VStack(spacing: 12) {
                    if cacheService.isDownloading {
                        VStack(spacing: 8) {
                            ProgressView(value: cacheService.downloadProgress)
                                .progressViewStyle(.linear)

                            Text("Downloading tiles… \(Int(cacheService.downloadProgress * 100))%")
                                .font(.caption)

                            Button("Cancel") {
                                cacheService.cancelDownload()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        Button {
                            downloadVisibleArea()
                        } label: {
                            Label("Download This Area", systemImage: "arrow.down.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("Download Map Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func downloadVisibleArea() {
        guard let region = visibleRegion else { return }
        cacheService.downloadArea(center: region.center, span: region.span)
    }
}
