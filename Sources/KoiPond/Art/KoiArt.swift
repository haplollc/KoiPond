//
//  KoiArt.swift
//  KoiPond
//
//  A koi from above, built along its spine: the body waves from head to
//  tail, the pectoral fins paddle, the tail streams.
//

import SwiftUI

// MARK: - Koi

enum KoiArt {
    /// Half-width along the body, nose (0) to the base of the tail (1).
    private static let knots: [(Double, Double)] = [(0, 0.46), (0.05, 0.76), (0.14, 0.94), (0.27, 1.0), (0.42, 0.93),
                                                    (0.58, 0.74), (0.74, 0.47), (0.87, 0.26), (1.0, 0.17)]

    static func profile(_ s: Double) -> Double {
        for i in 1..<knots.count where s <= knots[i].0 {
            let (s0, w0) = knots[i - 1], (s1, w1) = knots[i]
            let t = (s - s0) / (s1 - s0)
            let e = t * t * (3 - 2 * t)
            return w0 + (w1 - w0) * e
        }
        return knots.last!.1
    }

    /// The spine with the swimming wave laid on it: the tail sweeps further
    /// than the head, and the wave travels toward the tail.
    static func frames(_ k: KoiSnapshot) -> [(point: CGPoint, normal: CGVector, tangent: CGVector, s: Double)] {
        let n = k.spine.count
        return (0..<n).map { i in
            let a = k.spine[max(i - 1, 0)], b = k.spine[min(i + 1, n - 1)]
            var tx = a.x - b.x, ty = a.y - b.y
            let len = max(hypot(tx, ty), 0.0001)
            tx /= len; ty /= len
            let normal = CGVector(dx: -ty, dy: tx)
            let s = Double(i) / Double(n - 1)
            let wave = sin(k.swim - s * 5.2) * k.width * 0.55 * pow(s, 1.6)
            let p = CGPoint(x: k.spine[i].x + normal.dx * wave, y: k.spine[i].y + normal.dy * wave)
            return (p, normal, CGVector(dx: tx, dy: ty), s)
        }
    }

    static func bodyPath(_ k: KoiSnapshot, frames f: [(point: CGPoint, normal: CGVector, tangent: CGVector, s: Double)]) -> Path {
        var left: [CGPoint] = [], right: [CGPoint] = []
        for item in f {
            let w = profile(item.s) * k.width
            left.append(CGPoint(x: item.point.x + item.normal.dx * w, y: item.point.y + item.normal.dy * w))
            right.append(CGPoint(x: item.point.x - item.normal.dx * w, y: item.point.y - item.normal.dy * w))
        }
        let nose = CGPoint(x: f[0].point.x + f[0].tangent.dx * k.width * 0.32, y: f[0].point.y + f[0].tangent.dy * k.width * 0.32)
        return smoothClosed([nose] + left + right.reversed())
    }

    static func tailPath(_ k: KoiSnapshot, frames f: [(point: CGPoint, normal: CGVector, tangent: CGVector, s: Double)]) -> Path {
        let end = f[f.count - 1], before = f[f.count - 3]
        let back = CGVector(dx: -end.tangent.dx, dy: -end.tangent.dy)
        let n = end.normal
        let flutter = sin(k.swim - 5.6) * 0.45
        let len = k.width * 1.85, spread = k.width * 1.3
        func at(_ along: Double, _ across: Double) -> CGPoint {
            let swing = flutter * along
            return CGPoint(x: end.point.x + back.dx * along * len + n.dx * (across * spread + swing * spread),
                           y: end.point.y + back.dy * along * len + n.dy * (across * spread + swing * spread))
        }
        let base = profile(1) * k.width
        var path = Path()
        path.move(to: CGPoint(x: before.point.x + before.normal.dx * base, y: before.point.y + before.normal.dy * base))
        path.addQuadCurve(to: at(1.0, 0.95), control: at(0.45, 0.62))
        path.addQuadCurve(to: at(0.62, 0.05), control: at(0.86, 0.48))
        path.addQuadCurve(to: at(1.0, -0.95), control: at(0.86, -0.42))
        path.addQuadCurve(to: CGPoint(x: before.point.x - before.normal.dx * base, y: before.point.y - before.normal.dy * base),
                          control: at(0.45, -0.62))
        path.closeSubpath()
        return path
    }

    static func finPaths(_ k: KoiSnapshot, frames f: [(point: CGPoint, normal: CGVector, tangent: CGVector, s: Double)]) -> [Path] {
        let root = f[3]
        let w = profile(root.s) * k.width
        let back = CGVector(dx: -root.tangent.dx, dy: -root.tangent.dy)
        return [1.0, -1.0].map { side in
            let flap = 0.55 + 0.35 * sin(k.fin + (side > 0 ? 0 : .pi))
            let out = CGVector(dx: root.normal.dx * side, dy: root.normal.dy * side)
            let dir = CGVector(dx: out.dx * flap + back.dx * (1 - flap * 0.4), dy: out.dy * flap + back.dy * (1 - flap * 0.4))
            let len = k.width * 1.55
            let base = CGPoint(x: root.point.x + out.dx * w * 0.8, y: root.point.y + out.dy * w * 0.8)
            let tip = CGPoint(x: base.x + dir.dx * len, y: base.y + dir.dy * len)
            let side1 = CGPoint(x: base.x + back.dx * k.width * 0.55, y: base.y + back.dy * k.width * 0.55)
            var path = Path()
            path.move(to: base)
            path.addQuadCurve(to: tip, control: CGPoint(x: base.x + dir.dx * len * 0.5 - back.dx * 3, y: base.y + dir.dy * len * 0.5 - back.dy * 3))
            path.addQuadCurve(to: side1, control: CGPoint(x: tip.x + back.dx * k.width * 0.4, y: tip.y + back.dy * k.width * 0.4))
            path.closeSubpath()
            return path
        }
    }

    /// A koi's silhouette in one colour, for its shadow.
    static func fill(_ k: KoiSnapshot, in context: GraphicsContext, colour: Color) {
        let f = frames(k)
        context.fill(bodyPath(k, frames: f), with: .color(colour))
        context.fill(tailPath(k, frames: f), with: .color(colour.opacity(0.8)))
        for fin in finPaths(k, frames: f) { context.fill(fin, with: .color(colour.opacity(0.7))) }
    }

    static func draw(_ k: KoiSnapshot, in context: GraphicsContext) {
        let f = frames(k)
        var c = context
        c.opacity = k.opacity
        // Fish deeper down look a touch dimmer and bluer through the water.
        let murk = 0.18 * k.depth

        // Fins and tail first: translucent, under the body.
        let finColour = k.look.fins
        for fin in finPaths(k, frames: f) {
            c.fill(fin, with: .color(finColour.opacity(0.62)))
            c.stroke(fin, with: .color(.white.opacity(0.35)), lineWidth: 0.7)
        }
        let tail = tailPath(k, frames: f)
        c.fill(tail, with: .color(finColour.opacity(0.62)))
        // Fin rays.
        let end = f[f.count - 1]
        for ray in stride(from: -0.8, through: 0.8, by: 0.4) {
            var p = Path()
            p.move(to: end.point)
            p.addLine(to: CGPoint(x: end.point.x - end.tangent.dx * k.width * 1.7 + end.normal.dx * ray * k.width * 1.2,
                                  y: end.point.y - end.tangent.dy * k.width * 1.7 + end.normal.dy * ray * k.width * 1.2))
            c.stroke(p, with: .color(.white.opacity(0.14)), lineWidth: 0.5)
        }

        let body = bodyPath(k, frames: f)
        c.fill(body, with: .color(k.look.base))

        // Markings, clipped to the body.
        c.drawLayer { marks in
            marks.clip(to: body)
            for b in k.look.blotches {
                let i = min(max(Int(b.along * Double(f.count - 1)), 0), f.count - 1)
                let at = f[i]
                let w = profile(at.s) * k.width
                let centre = CGPoint(x: at.point.x + at.normal.dx * b.across * w, y: at.point.y + at.normal.dy * b.across * w)
                let angle = atan2(at.tangent.dy, at.tangent.dx) + b.turn
                let length = b.length * Double(f.count - 1) * hypot(k.spine[0].x - k.spine[1].x, k.spine[0].y - k.spine[1].y)
                let breadth = b.breadth * k.width
                var m = marks
                m.translateBy(x: centre.x, y: centre.y)
                m.rotate(by: .radians(angle))
                m.fill(Path(ellipseIn: CGRect(x: -length / 2, y: -breadth / 2, width: length, height: breadth)),
                       with: .color(b.colour))
            }
            // Depth and roundness: shade the flanks, light the spine.
            let sheen = k.look.sheen
            var spine = Path()
            spine.move(to: f[1].point)
            for item in f.dropFirst(2).prefix(f.count - 5) { spine.addLine(to: item.point) }
            marks.stroke(spine, with: .color(.white.opacity(sheen)), style: StrokeStyle(lineWidth: k.width * 0.55, lineCap: .round, lineJoin: .round))
            marks.stroke(body, with: .color(.black.opacity(0.22)), lineWidth: k.width * 0.35)
            if murk > 0.01 {
                marks.fill(body, with: .color(Color(red: 0.08, green: 0.22, blue: 0.40).opacity(murk)))
            }
        }
        c.stroke(body, with: .color(.black.opacity(0.18)), lineWidth: 0.6)

        // Eyes.
        let head = f[1]
        let wEye = profile(head.s) * k.width * 0.78
        for side in [1.0, -1.0] {
            let e = CGPoint(x: head.point.x + head.normal.dx * wEye * side, y: head.point.y + head.normal.dy * wEye * side)
            c.fill(Path(ellipseIn: CGRect(x: e.x - 1.6, y: e.y - 1.6, width: 3.2, height: 3.2)), with: .color(.black.opacity(0.85)))
            c.fill(Path(ellipseIn: CGRect(x: e.x - 1.0, y: e.y - 1.2, width: 1.0, height: 1.0)), with: .color(.white.opacity(0.8)))
        }
    }

    /// A smooth closed curve through the points (Catmull-Rom as cubics).
    static func smoothClosed(_ pts: [CGPoint]) -> Path {
        var path = Path()
        let n = pts.count
        guard n > 2 else { return path }
        path.move(to: pts[0])
        for i in 0..<n {
            let p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }
}
