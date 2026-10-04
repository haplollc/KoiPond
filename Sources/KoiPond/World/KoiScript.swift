//
//  KoiScript.swift
//  KoiPond
//
//  The choreography of a recorded take: what a finger does, and when. The
//  world plays it through the same touch handling a real finger goes
//  through, so a take shows exactly what a person would get.
//

import CoreGraphics

/// What a finger does in a recorded take, and when (seconds on the pond's
/// clock; points are fractions of the pond's size).
struct KoiScript: Sendable {
    enum Move: Sendable {
        /// A quick tap on the water.
        case tap(CGPoint)
        /// A finger drawn through the water along a path.
        case stroke([CGPoint], duration: Double)
        /// Grab a floater where it is, carry it along a path, and let go
        /// with a velocity (pt/s).
        case carry(FloatyKind, path: [CGPoint], duration: Double, release: CGVector)
        /// Drag the lily pad nearest a point along a path (where the pad
        /// goes), and let go with a velocity (pt/s).
        case drag(near: CGPoint, path: [CGPoint], duration: Double, release: CGVector)
        /// A tap on the mode control.
        case mode(KoiPondMode)
    }

    struct Beat: Sendable {
        var at: Double
        var move: Move
    }

    var beats: [Beat]
    var length: Double
    /// What the page shows when the take begins.
    var start: KoiPondMode = .pond

    /// The hero: play in the pool with the duck and the float, fill it into
    /// a koi pond, push a lily pad aside, feed and stir the koi, and drain
    /// it back to the pool.
    static let hero = KoiScript(beats: [
        // The floaters start where they're placed: the float at (0.36, 0.40),
        // the duck at (0.68, 0.62) facing down the pool. The duck goes round
        // the bottom half, clear of the float, and is set down below it...
        Beat(at: 1.0, move: .carry(.duck, path: [CGPoint(x: 0.60, y: 0.80), CGPoint(x: 0.36, y: 0.78),
                                                  CGPoint(x: 0.24, y: 0.62), CGPoint(x: 0.30, y: 0.56)],
                                    duration: 1.9, release: .zero)),
        // ...and the float is carried off above it and flung right, nearly
        // level (the release goes the way, and at the speed, the finger was
        // going), off the far wall and back across, still above the duck.
        Beat(at: 3.5, move: .carry(.tube, path: [CGPoint(x: 0.50, y: 0.40), CGPoint(x: 0.68, y: 0.38)], duration: 0.30,
                                    release: CGVector(dx: 560, dy: -100))),
        // A ripple out in the open water on the right.
        Beat(at: 5.2, move: .tap(CGPoint(x: 0.66, y: 0.66))),
        Beat(at: 6.9, move: .mode(.pond)),
        // The big pad top left pushed across the pond, shouldering the
        // others aside, and let go to drift.
        Beat(at: 7.8, move: .drag(near: CGPoint(x: 0.20, y: 0.27), path: [CGPoint(x: 0.33, y: 0.33),
                                                                     CGPoint(x: 0.50, y: 0.29)],
                                   duration: 1.2, release: CGVector(dx: 140, dy: -70))),
        // Food, twice; then a stir.
        Beat(at: 9.4, move: .tap(CGPoint(x: 0.50, y: 0.42))),
        Beat(at: 10.9, move: .tap(CGPoint(x: 0.33, y: 0.60))),
        // Straight through where they gathered to feed, scattering them up
        // and down the pond (one below them herded them all one way).
        Beat(at: 13.2, move: .stroke([CGPoint(x: 0.08, y: 0.60), CGPoint(x: 0.36, y: 0.53), CGPoint(x: 0.62, y: 0.57),
                                      CGPoint(x: 0.92, y: 0.50)], duration: 1.0)),
        Beat(at: 15.2, move: .mode(.pool)),
    ], length: 17.4, start: .pool)

    /// Just the pool: the duck carried round and set down, the float flung
    /// off the far wall, and taps whose rings rock the floaters.
    static let pool = KoiScript(beats: [
        Beat(at: 1.0, move: .carry(.duck, path: [CGPoint(x: 0.60, y: 0.80), CGPoint(x: 0.36, y: 0.78),
                                                  CGPoint(x: 0.24, y: 0.62), CGPoint(x: 0.30, y: 0.56)],
                                    duration: 1.9, release: .zero)),
        Beat(at: 3.5, move: .carry(.tube, path: [CGPoint(x: 0.50, y: 0.40), CGPoint(x: 0.68, y: 0.38)], duration: 0.30,
                                    release: CGVector(dx: 560, dy: -100))),
        Beat(at: 5.2, move: .tap(CGPoint(x: 0.66, y: 0.66))),
        Beat(at: 6.6, move: .tap(CGPoint(x: 0.38, y: 0.72))),
    ], length: 8.6, start: .pool)

    /// Just the pond: a lily pad pushed across, the koi fed twice, and a
    /// stir straight through where they gathered to feed, which scatters
    /// them up and down the pond (a stroke below them herded them all one
    /// way, and the take ended on a knot of fish).
    static let pond = KoiScript(beats: [
        Beat(at: 0.9, move: .drag(near: CGPoint(x: 0.20, y: 0.27), path: [CGPoint(x: 0.33, y: 0.33),
                                                                     CGPoint(x: 0.50, y: 0.29)],
                                   duration: 1.2, release: CGVector(dx: 140, dy: -70))),
        Beat(at: 2.6, move: .tap(CGPoint(x: 0.50, y: 0.42))),
        Beat(at: 4.1, move: .tap(CGPoint(x: 0.33, y: 0.60))),
        Beat(at: 6.4, move: .stroke([CGPoint(x: 0.08, y: 0.60), CGPoint(x: 0.36, y: 0.53), CGPoint(x: 0.62, y: 0.57),
                                     CGPoint(x: 0.92, y: 0.50)], duration: 1.0)),
    ], length: 9.8, start: .pond)
}

// MARK: - Curves

/// The shapes a scripted finger moves along, and how it speeds up.
enum Curves {
    /// A point a fraction `u` of the way along a path, through its points on
    /// a smooth curve. `u` goes by distance along the curve itself, so the
    /// pace is even however long or short each leg is; the ends carry
    /// straight on, so a path still has its speed when it finishes.
    static func point(along path: [CGPoint], at u: Double) -> CGPoint {
        guard path.count > 1 else { return path.first ?? .zero }
        var points: [CGPoint] = []
        for i in 0..<(path.count - 1) {
            let p1 = path[i], p2 = path[i + 1]
            let p0 = i > 0 ? path[i - 1] : CGPoint(x: 2 * p1.x - p2.x, y: 2 * p1.y - p2.y)
            let p3 = i + 2 < path.count ? path[i + 2] : CGPoint(x: 2 * p2.x - p1.x, y: 2 * p2.y - p1.y)
            for step in 0..<32 { points.append(catmullRom(p0, p1, p2, p3, Double(step) / 32)) }
        }
        points.append(path[path.count - 1])
        var lengths = [0.0]
        for i in 1..<points.count {
            lengths.append(lengths[i - 1] + hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y))
        }
        let goal = min(max(u, 0), 1) * lengths[lengths.count - 1]
        var i = 0
        while i < points.count - 2 && lengths[i + 1] < goal { i += 1 }
        let t = min(max((goal - lengths[i]) / max(lengths[i + 1] - lengths[i], 1e-6), 0), 1)
        return CGPoint(x: points[i].x + (points[i + 1].x - points[i].x) * t,
                       y: points[i].y + (points[i + 1].y - points[i].y) * t)
    }

    static func catmullRom(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: Double) -> CGPoint {
        func cr(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
            0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t * t * t)
        }
        return CGPoint(x: cr(p0.x, p1.x, p2.x, p3.x), y: cr(p0.y, p1.y, p2.y, p3.y))
    }

    /// Eases in and out: for a finger that sets something down.
    static func easeInOut(_ t: Double) -> Double { t * t * (3 - 2 * t) }

    /// Speeds up over the first third and keeps going to the end: for a
    /// finger that flings something, so it lets go at full speed.
    static func easeIn(_ t: Double) -> Double {
        let a = 0.3, v = 1 / (1 - a / 2)
        return t < a ? v * t * t / (2 * a) : v * (t - a / 2)
    }

    static func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

// MARK: - A seeded generator

/// A small, fast, seeded generator (SplitMix64), so every pond starts the
/// same way and a recorded take plays out the same every time.
struct SplitMix: Sendable {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    /// The next number, in 0 ..< 1.
    mutating func next() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }
}
