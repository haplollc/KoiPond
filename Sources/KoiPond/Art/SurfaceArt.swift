//
//  SurfaceArt.swift
//  KoiPond
//
//  What floats: lily pads and water lilies, and the pool's rubber duck and
//  striped float.
//

import SwiftUI

// MARK: - Lily pads and water lilies

enum LilyArt {
    static func padPath(_ p: LilyPadSnapshot) -> Path {
        let r = p.radius * (1 + p.bob * 0.012)
        var path = Path()
        path.move(to: p.center)
        let start = p.angle + p.notch / 2
        path.addLine(to: CGPoint(x: p.center.x + cos(start) * r, y: p.center.y + sin(start) * r))
        path.addArc(center: p.center, radius: r, startAngle: .radians(start), endAngle: .radians(p.angle + 2 * .pi - p.notch / 2), clockwise: false)
        path.closeSubpath()
        return path
    }

    static func draw(_ p: LilyPadSnapshot, in context: GraphicsContext) {
        var c = context
        c.opacity = p.opacity
        let path = padPath(p)
        let r = p.radius
        // Waxy green, yellowing a little on some pads.
        let inner = Color(red: 0.42 + 0.12 * p.tint, green: 0.62, blue: 0.24 - 0.06 * p.tint)
        let outer = Color(red: 0.16 + 0.06 * p.tint, green: 0.40, blue: 0.14)
        c.fill(path, with: .radialGradient(Gradient(colors: [inner, outer]), center: p.center, startRadius: 0, endRadius: r))
        // Veins from the centre.
        c.drawLayer { veins in
            veins.clip(to: path)
            let count = 15
            for i in 0..<count {
                let a = p.angle + p.notch / 2 + (2 * .pi - p.notch) * (Double(i) + 0.5) / Double(count)
                var v = Path()
                v.move(to: p.center)
                v.addQuadCurve(to: CGPoint(x: p.center.x + cos(a) * r, y: p.center.y + sin(a) * r),
                               control: CGPoint(x: p.center.x + cos(a + 0.08) * r * 0.5, y: p.center.y + sin(a + 0.08) * r * 0.5))
                veins.stroke(v, with: .color(Color(red: 0.75, green: 0.88, blue: 0.5).opacity(0.22)), lineWidth: 0.8)
            }
            // The waxy shine, from the upper left.
            veins.fill(Path(ellipseIn: CGRect(x: p.center.x - r * 0.9, y: p.center.y - r * 0.95, width: r * 1.2, height: r * 0.9)),
                       with: .radialGradient(Gradient(colors: [.white.opacity(0.20), .white.opacity(0)]),
                                             center: CGPoint(x: p.center.x - r * 0.35, y: p.center.y - r * 0.5), startRadius: 0, endRadius: r * 0.7))
        }
        // A curled, darker rim.
        c.stroke(path, with: .color(Color(red: 0.10, green: 0.27, blue: 0.10).opacity(0.75)), lineWidth: 1.4)

        if let flower = p.flower { drawFlower(flower, on: p, in: c) }
    }

    static func drawFlower(_ f: LilyFlower, on p: LilyPadSnapshot, in context: GraphicsContext) {
        let centre = CGPoint(x: p.center.x + f.offset.dx, y: p.center.y + f.offset.dy)
        let tip = Color(red: 0.98, green: 0.55 + 0.3 * (1 - f.pink), blue: 0.72 + 0.2 * (1 - f.pink))
        let heart = Color(red: 1.0, green: 0.97, blue: 0.95)
        let c = context
        // Its own soft shadow on the pad.
        c.fill(Path(ellipseIn: CGRect(x: centre.x - f.radius + 4, y: centre.y - f.radius + 6, width: f.radius * 2, height: f.radius * 2)),
               with: .radialGradient(Gradient(colors: [.black.opacity(0.28), .black.opacity(0)]), center: CGPoint(x: centre.x + 4, y: centre.y + 6),
                                     startRadius: 0, endRadius: f.radius))
        // Two rings of pointed petals, the inner smaller and paler.
        for (ring, scale, count, shade) in [(0, 1.0, f.petals, 1.0), (1, 0.66, f.petals - 2, 0.55)] {
            for i in 0..<count {
                let a = f.turn + Double(ring) * 0.3 + Double(i) / Double(count) * 2 * .pi
                let len = f.radius * scale
                var petal = Path()
                let base = centre
                let end = CGPoint(x: base.x + cos(a) * len, y: base.y + sin(a) * len)
                let w = len * 0.30
                let mid = CGPoint(x: base.x + cos(a) * len * 0.5, y: base.y + sin(a) * len * 0.5)
                let l = CGPoint(x: mid.x - sin(a) * w, y: mid.y + cos(a) * w)
                let r = CGPoint(x: mid.x + sin(a) * w, y: mid.y - cos(a) * w)
                petal.move(to: base)
                petal.addQuadCurve(to: end, control: l)
                petal.addQuadCurve(to: base, control: r)
                let colours = [heart, ring == 0 ? tip : tip.opacity(0.6 + 0.4 * shade)]
                c.fill(petal, with: .linearGradient(Gradient(colors: colours), startPoint: base, endPoint: end))
                c.stroke(petal, with: .color(Color(red: 0.85, green: 0.45, blue: 0.6).opacity(0.25)), lineWidth: 0.5)
            }
        }
        // The golden heart.
        let core = f.radius * 0.24
        c.fill(Path(ellipseIn: CGRect(x: centre.x - core, y: centre.y - core, width: core * 2, height: core * 2)),
               with: .radialGradient(Gradient(colors: [Color(red: 1.0, green: 0.9, blue: 0.35), Color(red: 0.95, green: 0.68, blue: 0.12)]),
                                     center: centre, startRadius: 0, endRadius: core))
        for i in 0..<12 {
            let a = Double(i) / 12 * 2 * .pi
            let d = CGPoint(x: centre.x + cos(a) * core * 0.75, y: centre.y + sin(a) * core * 0.75)
            c.fill(Path(ellipseIn: CGRect(x: d.x - 1.1, y: d.y - 1.1, width: 2.2, height: 2.2)), with: .color(Color(red: 1.0, green: 0.95, blue: 0.6)))
        }
    }
}

// MARK: - The pool's floaters

enum FloatyArt {
    /// The duck is drawn a size up on its 90 pt design, to hold its own
    /// next to the float.
    static let duckScale = 1.2

    static func shadow(_ f: FloatySnapshot, in context: GraphicsContext) {
        var c = context
        c.translateBy(x: f.center.x, y: f.center.y)
        c.rotate(by: .radians(f.angle))
        c.scaleBy(x: f.scale, y: f.scale)
        if f.kind == .duck { c.scaleBy(x: duckScale, y: duckScale) }
        switch f.kind {
        case .tube:
            var ring = Path(ellipseIn: CGRect(x: -52, y: -52, width: 104, height: 104))
            ring.addPath(Path(ellipseIn: CGRect(x: -22, y: -22, width: 44, height: 44)))
            c.fill(ring, with: .color(.black), style: FillStyle(eoFill: true))
        case .duck:
            c.fill(duckBody(), with: .color(.black))
            c.fill(Path(ellipseIn: CGRect(x: 6, y: -14, width: 28, height: 28)), with: .color(.black))
        }
    }

    static func draw(_ f: FloatySnapshot, in context: GraphicsContext) {
        var c = context
        c.opacity = f.opacity
        c.translateBy(x: f.center.x, y: f.center.y)
        c.rotate(by: .radians(f.angle))
        let bob = 1 + f.bob * 0.02
        let own = f.kind == .duck ? duckScale : 1
        c.scaleBy(x: f.scale * bob * own, y: f.scale * bob * own)
        switch f.kind {
        case .tube: drawTube(in: c)
        case .duck: drawDuck(in: c)
        }
    }

    /// A striped inflatable ring, seen from above: rounded like a tube by a
    /// band of shading across it, with a gloss on the side facing the sun.
    static func drawTube(in c: GraphicsContext) {
        let outer = 52.0, inner = 22.0
        let stripes = 10
        let coral = Color(red: 1.0, green: 0.36, blue: 0.42)
        let cream = Color(red: 1.0, green: 0.97, blue: 0.92)
        for i in 0..<stripes {
            let a0 = Double(i) / Double(stripes) * 2 * .pi, a1 = Double(i + 1) / Double(stripes) * 2 * .pi
            var seg = Path()
            seg.addArc(center: .zero, radius: outer, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
            seg.addArc(center: .zero, radius: inner, startAngle: .radians(a1), endAngle: .radians(a0), clockwise: true)
            seg.closeSubpath()
            c.fill(seg, with: .color(i % 2 == 0 ? coral : cream))
        }
        var ring = Path(ellipseIn: CGRect(x: -outer, y: -outer, width: outer * 2, height: outer * 2))
        ring.addPath(Path(ellipseIn: CGRect(x: -inner, y: -inner, width: inner * 2, height: inner * 2)))
        // Roundness: dark at both edges of the tube, lightest along its crown.
        let mid = (inner + outer) / 2
        c.fill(ring, with: .radialGradient(Gradient(stops: [
            .init(color: .black.opacity(0.30), location: inner / outer),
            .init(color: .black.opacity(0.0), location: (inner + (mid - inner) * 0.6) / outer),
            .init(color: .white.opacity(0.10), location: mid / outer),
            .init(color: .black.opacity(0.0), location: (mid + (outer - mid) * 0.45) / outer),
            .init(color: .black.opacity(0.32), location: 1.0),
        ]), center: .zero, startRadius: 0, endRadius: outer), style: FillStyle(eoFill: true))
        // Gloss toward the sun.
        var gloss = Path()
        gloss.addArc(center: .zero, radius: mid + 2, startAngle: .degrees(195), endAngle: .degrees(265), clockwise: false)
        c.stroke(gloss, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        var glint = Path()
        glint.addArc(center: .zero, radius: mid - 4, startAngle: .degrees(20), endAngle: .degrees(40), clockwise: false)
        c.stroke(glint, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        // The valve.
        c.fill(Path(roundedRect: CGRect(x: -4, y: outer - 9, width: 8, height: 6), cornerRadius: 2), with: .color(cream))
        c.stroke(ring, with: .color(.black.opacity(0.12)), style: StrokeStyle(lineWidth: 0.8))
    }

    static func duckBody() -> Path {
        // Facing +x: a plump teardrop with a perky tail at the back.
        var p = Path()
        p.move(to: CGPoint(x: 24, y: 0))
        p.addCurve(to: CGPoint(x: -22, y: 21), control1: CGPoint(x: 24, y: 22), control2: CGPoint(x: -8, y: 26))
        p.addCurve(to: CGPoint(x: -38, y: 0), control1: CGPoint(x: -32, y: 17), control2: CGPoint(x: -40, y: 8))
        p.addCurve(to: CGPoint(x: -22, y: -21), control1: CGPoint(x: -40, y: -8), control2: CGPoint(x: -32, y: -17))
        p.addCurve(to: CGPoint(x: 24, y: 0), control1: CGPoint(x: -8, y: -26), control2: CGPoint(x: 24, y: -22))
        p.closeSubpath()
        return p
    }

    /// A rubber duck from above, facing its direction of travel: glossy
    /// yellow body and wings, a round head, an orange bill, bead eyes.
    static func drawDuck(in c: GraphicsContext) {
        let yellow = Color(red: 1.0, green: 0.84, blue: 0.12)
        let deep = Color(red: 0.98, green: 0.68, blue: 0.05)
        let body = duckBody()
        c.fill(body, with: .radialGradient(Gradient(colors: [Color(red: 1.0, green: 0.95, blue: 0.55), yellow, deep]),
                                           center: CGPoint(x: -10, y: -8), startRadius: 0, endRadius: 40))
        // Wings, folded along the sides.
        for side in [1.0, -1.0] {
            var wing = Path()
            wing.move(to: CGPoint(x: 6, y: 14 * side))
            wing.addQuadCurve(to: CGPoint(x: -26, y: 13 * side), control: CGPoint(x: -8, y: 24 * side))
            wing.addQuadCurve(to: CGPoint(x: 6, y: 14 * side), control: CGPoint(x: -10, y: 8 * side))
            c.fill(wing, with: .color(deep.opacity(0.55)))
        }
        // The tail flick.
        var tail = Path()
        tail.move(to: CGPoint(x: -34, y: -5))
        tail.addQuadCurve(to: CGPoint(x: -46, y: 0), control: CGPoint(x: -44, y: -6))
        tail.addQuadCurve(to: CGPoint(x: -34, y: 5), control: CGPoint(x: -44, y: 6))
        c.fill(tail, with: .color(yellow))
        c.stroke(body, with: .color(Color(red: 0.75, green: 0.5, blue: 0.0).opacity(0.25)), lineWidth: 0.8)

        // The bill, under the head's front.
        var bill = Path()
        bill.move(to: CGPoint(x: 26, y: -7))
        bill.addQuadCurve(to: CGPoint(x: 44, y: 0), control: CGPoint(x: 42, y: -8))
        bill.addQuadCurve(to: CGPoint(x: 26, y: 7), control: CGPoint(x: 42, y: 8))
        bill.closeSubpath()
        c.fill(bill, with: .linearGradient(Gradient(colors: [Color(red: 1.0, green: 0.62, blue: 0.1), Color(red: 0.95, green: 0.42, blue: 0.05)]),
                                           startPoint: CGPoint(x: 26, y: 0), endPoint: CGPoint(x: 44, y: 0)))
        // Head.
        let head = Path(ellipseIn: CGRect(x: 6, y: -15, width: 30, height: 30))
        c.fill(head, with: .radialGradient(Gradient(colors: [Color(red: 1.0, green: 0.97, blue: 0.68), yellow, deep]),
                                           center: CGPoint(x: 15, y: -6), startRadius: 0, endRadius: 22))
        c.stroke(head, with: .color(Color(red: 0.75, green: 0.5, blue: 0.0).opacity(0.22)), lineWidth: 0.7)
        // Eyes on either side of the head.
        for side in [1.0, -1.0] {
            let e = CGPoint(x: 24, y: 9.5 * side)
            c.fill(Path(ellipseIn: CGRect(x: e.x - 3, y: e.y - 3, width: 6, height: 6)), with: .color(Color(red: 0.08, green: 0.08, blue: 0.1)))
            c.fill(Path(ellipseIn: CGRect(x: e.x - 1.6, y: e.y - 2.2, width: 2, height: 2)), with: .color(.white.opacity(0.9)))
        }
        // Shine.
        c.fill(Path(ellipseIn: CGRect(x: -20, y: -16, width: 16, height: 8)), with: .color(.white.opacity(0.45)))
        c.fill(Path(ellipseIn: CGRect(x: 12, y: -11, width: 9, height: 5)), with: .color(.white.opacity(0.55)))
    }
}
