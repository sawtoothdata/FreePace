//
//  MapTileCacheService.swift
//  Run-Tracker
//

import Foundation
import MapKit

@Observable
final class MapTileCacheService {
    static let shared = MapTileCacheService()

    private(set) var isDownloading = false
    private(set) var downloadProgress: Double = 0
    private(set) var cacheSizeBytes: Int = 0

    private let tileCache: URLCache
    private let session: URLSession
    private var downloadTask: Task<Void, Never>?

    private static let memoryCacheSize = 50_000_000  // 50 MB
    private static let diskCacheSize = 500_000_000    // 500 MB

    private init() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MapTileCache", isDirectory: true)

        tileCache = URLCache(
            memoryCapacity: Self.memoryCacheSize,
            diskCapacity: Self.diskCacheSize,
            directory: cacheDir
        )

        let config = URLSessionConfiguration.default
        config.urlCache = tileCache
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)

        updateCacheSize()
    }

    // MARK: - Cache Info

    var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(cacheSizeBytes), countStyle: .file)
    }

    func updateCacheSize() {
        cacheSizeBytes = tileCache.currentDiskUsage
    }

    // MARK: - Clear Cache

    func clearCache() {
        tileCache.removeAllCachedResponses()
        updateCacheSize()
    }

    // MARK: - Cache Named Route

    func cacheRoute(_ route: NamedRoute) {
        // Compute bounding box from all route points across all runs
        let allPoints = route.runs.flatMap(\.routePoints)
        guard !allPoints.isEmpty else { return }

        let lats = allPoints.map(\.latitude)
        let lons = allPoints.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        // Add 10% padding
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.1,
            longitudeDelta: (maxLon - minLon) * 1.1
        )
        downloadArea(center: center, span: span)
    }

    // MARK: - Download Map Area

    func downloadArea(center: CLLocationCoordinate2D, span: MKCoordinateSpan) {
        guard !isDownloading else { return }

        isDownloading = true
        downloadProgress = 0

        downloadTask = Task { [weak self] in
            guard let self else { return }

            let tileURLs = self.enumerateTileURLs(center: center, span: span, minZoom: 10, maxZoom: 16)
            let total = tileURLs.count
            guard total > 0 else {
                await MainActor.run {
                    self.isDownloading = false
                    self.updateCacheSize()
                }
                return
            }

            var completed = 0
            for url in tileURLs {
                if Task.isCancelled { break }

                let request = URLRequest(url: url)
                // Skip if already cached
                if self.tileCache.cachedResponse(for: request) != nil {
                    completed += 1
                    let progress = Double(completed) / Double(total)
                    await MainActor.run { self.downloadProgress = progress }
                    continue
                }

                do {
                    let (data, response) = try await self.session.data(for: request)
                    let cachedResponse = CachedURLResponse(response: response, data: data)
                    self.tileCache.storeCachedResponse(cachedResponse, for: request)
                } catch {
                    // Continue on failure — best-effort download
                }

                completed += 1
                let progress = Double(completed) / Double(total)
                await MainActor.run { self.downloadProgress = progress }
            }

            await MainActor.run {
                self.isDownloading = false
                self.downloadProgress = 1.0
                self.updateCacheSize()
            }
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
    }

    // MARK: - Tile URL Enumeration

    private func enumerateTileURLs(
        center: CLLocationCoordinate2D,
        span: MKCoordinateSpan,
        minZoom: Int,
        maxZoom: Int
    ) -> [URL] {
        var urls: [URL] = []

        let minLat = center.latitude - span.latitudeDelta / 2
        let maxLat = center.latitude + span.latitudeDelta / 2
        let minLon = center.longitude - span.longitudeDelta / 2
        let maxLon = center.longitude + span.longitudeDelta / 2

        for zoom in minZoom...maxZoom {
            let minTileX = lonToTileX(minLon, zoom: zoom)
            let maxTileX = lonToTileX(maxLon, zoom: zoom)
            let minTileY = latToTileY(maxLat, zoom: zoom) // Note: Y is inverted
            let maxTileY = latToTileY(minLat, zoom: zoom)

            for x in minTileX...maxTileX {
                for y in minTileY...maxTileY {
                    // Use OpenStreetMap tile server as a representative URL
                    // In production, this would use the appropriate tile server
                    let urlStr = "https://tile.openstreetmap.org/\(zoom)/\(x)/\(y).png"
                    if let url = URL(string: urlStr) {
                        urls.append(url)
                    }
                }
            }
        }

        return urls
    }

    private func lonToTileX(_ lon: Double, zoom: Int) -> Int {
        Int(floor((lon + 180.0) / 360.0 * pow(2.0, Double(zoom))))
    }

    private func latToTileY(_ lat: Double, zoom: Int) -> Int {
        let latRad = lat * .pi / 180.0
        return Int(floor((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / .pi) / 2.0 * pow(2.0, Double(zoom))))
    }
}
