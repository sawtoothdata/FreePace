//
//  RouteSnapshotView.swift
//  Run-Tracker
//

import SwiftUI
import MapKit

struct RouteSnapshotView: View {
    let coordinates: [(Double, Double)] // (latitude, longitude)
    var lineColor: Color = .blue
    var size: CGSize = CGSize(width: 56, height: 56)

    @Environment(\.colorScheme) private var colorScheme
    @State private var snapshotImage: UIImage?

    var body: some View {
        Group {
            if let image = snapshotImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: coordinateHash) {
            await generateSnapshot()
        }
    }

    private var coordinateHash: Int {
        var hasher = Hasher()
        hasher.combine(coordinates.count)
        if let first = coordinates.first {
            hasher.combine(first.0)
            hasher.combine(first.1)
        }
        if let last = coordinates.last {
            hasher.combine(last.0)
            hasher.combine(last.1)
        }
        hasher.combine(colorScheme)
        return hasher.finalize()
    }

    private func generateSnapshot() async {
        guard coordinates.count >= 2 else { return }

        let clCoords = coordinates.map {
            CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1)
        }

        // Compute region with padding
        let lats = coordinates.map(\.0)
        let lons = coordinates.map(\.1)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.4 + 0.001,
            longitudeDelta: (maxLon - minLon) * 1.4 + 0.001
        )
        let region = MKCoordinateRegion(center: center, span: span)

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: size.width * 2, height: size.height * 2)
        options.scale = UITraitCollection.current.displayScale
        if colorScheme == .dark {
            options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        }

        let snapshotter = MKMapSnapshotter(options: options)

        do {
            let snapshot = try await snapshotter.start()
            let image = drawRoute(on: snapshot, coordinates: clCoords)
            await MainActor.run {
                snapshotImage = image
            }
        } catch {
            // Silently fail — thumbnail is non-critical
        }
    }

    private func drawRoute(
        on snapshot: MKMapSnapshotter.Snapshot,
        coordinates: [CLLocationCoordinate2D]
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: snapshot.image.size)
        return renderer.image { ctx in
            snapshot.image.draw(at: .zero)

            let path = UIBezierPath()
            for (i, coord) in coordinates.enumerated() {
                let point = snapshot.point(for: coord)
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            UIColor(lineColor).setStroke()
            path.lineWidth = 3
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
    }
}
