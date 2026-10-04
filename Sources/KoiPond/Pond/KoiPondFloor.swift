//
//  KoiPondFloor.swift
//  KoiPond
//
//  The ready-made pond's two floors: a bed of silt and pebbles for the koi,
//  pale tiles and a lane stripe for the pool. Each is drawn once per size
//  into an image (hundreds of pebbles redrawn every frame would be a waste)
//  and they crossfade on the pond's own clock, so a slowed-down recording
//  keeps them in step with the water.
//

import SwiftUI

extension EnvironmentValues {
    /// How far the pond has turned into a pool (0 pond … 1 pool), on the
    /// pond's own clock, for a floor that changes with it.
    @Entry var koiPoolMix: Double = 0
}

struct KoiPondFloor: View {
    @Environment(\.koiPoolMix) private var poolMix
    @Environment(\.displayScale) private var scale
    @State private var pebbles: Image?
    @State private var tiles: Image?
    @State private var renderedSize: CGSize = .zero

    var body: some View {
        ZStack {
            Group {
                if let pebbles { pebbles.resizable() } else { KoiPondPebbles() }
            }
            // The tiles come in over the middle of a switch (and go the same
            // way), so neither floor lingers long under the other's water,
            // nor does the switch flip over all at once.
            let shown = min(max((poolMix - 0.2) / 0.7, 0), 1)
            Group {
                if let tiles { tiles.resizable() } else { KoiPoolTiles() }
            }
            .opacity(shown * shown * (3 - 2 * shown))
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { render(at: $0) }
    }

    private func render(at size: CGSize) {
        guard size.width > 1, size.height > 1, size != renderedSize else { return }
        renderedSize = size
        pebbles = snapshot(KoiPondPebbles(), size: size)
        tiles = snapshot(KoiPoolTiles(), size: size)
    }

    private func snapshot<V: View>(_ view: V, size: CGSize) -> Image? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        return renderer.cgImage.map { Image(decorative: $0, scale: scale) }
    }
}

/// A pond's bed: dark silt, fine gravel and a scatter of smooth stones,
/// kept darker than the fish so the koi are the brightest thing in the water.
struct KoiPondPebbles: View {
    /// Cool greys, one or two a little warm, under blue water.
    private static let stones: [(red: Double, green: Double, blue: Double)] = [
        (0.44, 0.46, 0.48), (0.36, 0.38, 0.41),
        (0.52, 0.53, 0.53), (0.29, 0.32, 0.36),
        (0.43, 0.40, 0.36), (0.27, 0.33, 0.37),
        (0.56, 0.57, 0.58),
    ]

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.14, green: 0.25, blue: 0.33), Color(red: 0.07, green: 0.15, blue: 0.23)]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            var rng = SplitMix(seed: 0x51E7)
            // Darker hollows in the silt.
            for _ in 0..<16 {
                let p = CGPoint(x: rng.next() * size.width, y: rng.next() * size.height)
                let r = 60 + rng.next() * 130
                context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r * 0.7, width: r * 2, height: r * 1.4)),
                             with: .radialGradient(Gradient(colors: [.black.opacity(0.28), .black.opacity(0)]), center: p, startRadius: 0, endRadius: r))
            }
            // Smooth stones.
            let count = Int(size.width * size.height / 1600)
            for _ in 0..<count {
                let p = CGPoint(x: rng.next() * size.width, y: rng.next() * size.height)
                let r = 3 + pow(rng.next(), 2.6) * 17
                let aspect = 0.6 + rng.next() * 0.35
                let stone = Self.stones[Int(rng.next() * Double(Self.stones.count)) % Self.stones.count]
                var c = context
                c.translateBy(x: p.x, y: p.y)
                c.rotate(by: .radians(rng.next() * .pi))
                let rect = CGRect(x: -r, y: -r * aspect, width: r * 2, height: r * 2 * aspect)
                c.fill(Path(ellipseIn: rect.offsetBy(dx: 1.2, dy: 1.8)), with: .color(.black.opacity(0.4)))
                c.fill(Path(ellipseIn: rect), with: .radialGradient(
                    Gradient(colors: [Self.shade(stone, toward: 1, by: 0.12), Self.colour(stone), Self.shade(stone, toward: 0, by: 0.25)]),
                    center: CGPoint(x: -r * 0.3, y: -r * 0.35), startRadius: 0, endRadius: r * 1.25))
            }
        }
        .accessibilityHidden(true)
    }

    private static func colour(_ stone: (red: Double, green: Double, blue: Double)) -> Color {
        Color(red: stone.red, green: stone.green, blue: stone.blue)
    }

    /// A stone lit (toward white) or shaded (toward black): mixed
    /// perceptually where SwiftUI can, else straight across, which on these
    /// small greys looks the same.
    private static func shade(_ stone: (red: Double, green: Double, blue: Double), toward target: Double, by fraction: Double) -> Color {
        if #available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *) {
            return colour(stone).mix(with: target > 0.5 ? .white : .black, by: fraction)
        }
        func toward(_ v: Double) -> Double { v + (target - v) * fraction }
        return Color(red: toward(stone.red), green: toward(stone.green), blue: toward(stone.blue))
    }
}

/// A pool's floor: pale aqua tiles with white grout and a lane stripe.
struct KoiPoolTiles: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.70, green: 0.90, blue: 0.95)))
            let tile = 26.0
            var rng = SplitMix(seed: 0x7113)
            // Laid out from the middle, so the lane sits centred on a grout line.
            let first = (size.width / 2).truncatingRemainder(dividingBy: tile) - tile
            var y = 0.0
            while y < size.height {
                var x = first
                while x < size.width {
                    let v = (rng.next() - 0.5) * 0.05
                    context.fill(Path(CGRect(x: x + 0.8, y: y + 0.8, width: tile - 1.6, height: tile - 1.6)),
                                 with: .color(Color(red: 0.66 + v, green: 0.87 + v, blue: 0.93 + v)))
                    x += tile
                }
                y += tile
            }
            // The lane stripe, with its T near each end.
            let lane = Color(red: 0.10, green: 0.30, blue: 0.55)
            let stripe = tile * 0.9
            let mid = size.width / 2
            // Four tiles in from each wall, clear of a control along the bottom.
            let top = tile * 4, bottom = size.height - tile * 4
            context.fill(Path(CGRect(x: mid - stripe / 2, y: top, width: stripe, height: bottom - top)), with: .color(lane))
            for end in [top, bottom - stripe] {
                context.fill(Path(CGRect(x: mid - tile * 2.5, y: end, width: tile * 5, height: stripe)), with: .color(lane))
            }
        }
        .accessibilityHidden(true)
    }
}
