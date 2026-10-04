//
//  CurvesTests.swift
//  KoiPondTests
//
//  The paths a recorded take's finger follows. A finger that sped up and
//  slowed down with the spacing of the points it was given would look
//  mechanical; this checks it keeps an even pace by distance along the
//  curve, starts and ends where it should, and lets go of a fling at full
//  speed.
//

import CoreGraphics
import Testing
@testable import KoiPond

struct CurvesTests {

    /// Uneven legs: a short hop, a long sweep, a short hop.
    private let uneven = [CGPoint(x: 0, y: 0), CGPoint(x: 20, y: 10), CGPoint(x: 300, y: 80), CGPoint(x: 320, y: 60)]

    /// The size of the pond on an iPhone 17 Pro Max, the takes' stage.
    private let pond = CGSize(width: 440, height: 956)

    @Test func startsAndEndsOnThePath() {
        let start = Curves.point(along: uneven, at: 0), end = Curves.point(along: uneven, at: 1)
        #expect(hypot(start.x - 0, start.y - 0) < 1e-9)
        #expect(hypot(end.x - 320, end.y - 60) < 1e-9)
        // Outside 0…1 it stays at the ends.
        #expect(Curves.point(along: uneven, at: -0.5) == start)
        #expect(Curves.point(along: uneven, at: 1.5) == end)
    }

    @Test func passesThroughEveryPoint() {
        let samples = (0...2_000).map { Curves.point(along: uneven, at: Double($0) / 2_000) }
        for p in uneven {
            let nearest = samples.map { hypot($0.x - p.x, $0.y - p.y) }.min() ?? .infinity
            #expect(nearest < 0.5, "missed \(p) by \(nearest) pt")
        }
    }

    @Test func aSinglePointStaysPut() {
        #expect(Curves.point(along: [CGPoint(x: 5, y: 7)], at: 0.4) == CGPoint(x: 5, y: 7))
        #expect(Curves.point(along: [], at: 0.4) == .zero)
    }

    /// Equal steps of `u` cover equal distances along the curve, however
    /// long or short each leg is.
    @Test func keepsAnEvenPaceAlongTheCurve() {
        let steps = 20, dense = 50
        let arcs = (0..<steps).map { k in
            let points = (0...dense).map { j in Curves.point(along: uneven, at: Double(k * dense + j) / Double(steps * dense)) }
            return zip(points, points.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }.reduce(0, +)
        }
        let mean = arcs.reduce(0, +) / Double(steps)
        for arc in arcs {
            #expect(abs(arc - mean) / mean < 0.02, "\(arcs)")
        }
    }

    /// The takes' own paths, at 60 frames: a finger moves the same distance
    /// on every frame.
    @Test(arguments: [KoiScript.pool, KoiScript.pond])
    func theTakesPathsMoveEvenlyFrameToFrame(_ script: KoiScript) {
        for beat in script.beats {
            let path: [CGPoint]
            switch beat.move {
            case .carry(_, let p, _, _), .stroke(let p, _), .drag(_, let p, _, _): path = p
            case .tap, .mode: continue
            }
            let points = path.map { CGPoint(x: $0.x * pond.width, y: $0.y * pond.height) }
            let frames = 60
            let at = (0...frames).map { Curves.point(along: points, at: Double($0) / Double(frames)) }
            let steps = zip(at, at.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
            let mean = steps.reduce(0, +) / Double(frames)
            #expect(steps.allSatisfy { abs($0 - mean) / mean < 0.05 }, "uneven steps on \(path): \(steps)")
        }
    }

    @Test func easeInOutSetsThingsDownGently() {
        #expect(Curves.easeInOut(0) == 0)
        #expect(Curves.easeInOut(1) == 1)
        #expect(Curves.easeInOut(0.5) == 0.5)
        // At rest at both ends, symmetric about the middle.
        let e = 1e-4
        #expect(Curves.easeInOut(e) / e < 0.01)
        #expect((1 - Curves.easeInOut(1 - e)) / e < 0.01)
        for t in stride(from: 0.0, through: 1.0, by: 0.05) {
            #expect(abs(Curves.easeInOut(t) + Curves.easeInOut(1 - t) - 1) < 1e-12)
        }
    }

    /// A fling speeds up over the first third, then holds its speed to the
    /// end: the finger lets go at full speed, so what it threw keeps going.
    @Test func easeInLetsGoAtFullSpeed() {
        #expect(Curves.easeIn(0) == 0)
        #expect(abs(Curves.easeIn(1) - 1) < 1e-12)
        let e = 1e-6
        // No jump where the speeding-up ends.
        #expect(abs(Curves.easeIn(0.3 - e) - Curves.easeIn(0.3 + e)) < 1e-5)
        // The same speed from there to the end.
        func slope(_ t: Double) -> Double { (Curves.easeIn(t + e) - Curves.easeIn(t - e)) / (2 * e) }
        #expect(abs(slope(0.5) - slope(0.999)) < 1e-6)
        #expect(slope(0.999) > 1)
        // Always going forward.
        var last = -1.0
        for t in stride(from: 0.0, through: 1.0, by: 0.01) {
            let v = Curves.easeIn(t)
            #expect(v > last)
            last = v
        }
    }
}
