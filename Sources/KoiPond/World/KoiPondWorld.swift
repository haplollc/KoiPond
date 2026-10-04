//
//  KoiPondWorld.swift
//  KoiPond
//
//  Everything that lives in the pond, stepped on one clock: koi that wander,
//  keep their distance from each other, shy away from a finger and race for
//  food; lily pads and their flowers drifting on a slow current; the pool's
//  rubber duck and float, which you can grab and fling; and the ripples all
//  of them leave for the water shader (KoiPond.metal) to draw.
//

import SwiftUI

@MainActor
final class KoiPondWorld {

    /// How a pond starts: applied once, before its first step.
    struct Setup {
        var mode: KoiPondMode
        var koi: Int
        var keepClear: EdgeInsets
        var take: KoiPondTake?
    }

    private struct Koi {
        var spine: [CGPoint]
        var heading: Double
        var speed: Double
        var cruise: Double
        var length: Double
        var width: Double
        var swim: Double
        var fin: Double
        var seed: Double
        var depth: Double
        var surfacing: Double = 0
        var lastRing: Double = 0
        var look: KoiLook
    }

    private struct Pad {
        var center: CGPoint
        var velocity: CGVector = .zero
        var radius: Double
        var angle: Double
        var spin: Double
        /// Extra turning from fish bumping it from below; dies away.
        var turn: Double = 0
        var notch: Double
        var tint: Double
        var flower: LilyFlower?
    }

    private struct Floaty {
        var kind: FloatyKind
        var center: CGPoint
        var velocity: CGVector = .zero
        var angle: Double
        var spin: Double
        var radius: Double
        var lastRing: Double = 0
        /// How much wake it's trailing (0…1): it builds as the floater gets
        /// going rather than appearing whole the moment it's grabbed.
        var wake: Double = 0
    }

    private struct Pellet {
        var point: CGPoint
        var drift: CGVector
        var born: Double
    }

    /// A ring on the water; `source` is the floater that made it (-1 for
    /// a finger, a fish or a landing), so a floater isn't pushed by its own.
    private struct Ripple {
        var x, y, born, strength: Double
        var source = -1
        /// A tail-beat swirl: a small ring that fades within a second.
        var small = false
    }

    // Configuration
    private(set) var mode: KoiPondMode = .pond
    private(set) var koiCount = 7
    /// Clock divider for recordings.
    private(set) var pace = 1.0
    /// Room the floaters keep from the edges (under a control, the Dynamic
    /// Island): one that strays in is eased back out.
    var keepClear = EdgeInsets()
    /// The pond's size relative to a 400 pt one: fish, pads and floaters scale with it.
    private var scale = 1.0
    private var isSetUp = false

    // State
    private var size: CGSize = .zero
    private var epoch: Date?
    private var clock = 0.0
    private var poolMix = 0.0
    private var poolMixSpeed = 0.0
    private var koi: [Koi] = []
    private var pads: [Pad] = []
    private var floaties: [Floaty] = []
    private var pellets: [Pellet] = []
    private var ripples: [Ripple] = []
    private var rng = SplitMix(seed: 0xC0FFEE)
    private var landingAt: Double?
    private var dropped = 0
    private var eaten = 0

    // Touch
    private var finger: CGPoint?
    private var touchStart: (point: CGPoint, time: Double)?
    private var lastFingerRing: (point: CGPoint, time: Double)?
    private var grabbed: Int?
    private var grabOffset: CGVector = .zero
    private var grabTrail: [(CGPoint, Double)] = []
    /// A lily pad under a finger that went down on it: a drag takes it
    /// along (a tap still feeds the fish).
    private var padUnderFinger: Int?
    private var grabbedPad: Int?
    private var padGrabOffset: CGVector = .zero
    private var lastPadRing = -1.0
    private var releasedSince: Date?

    // A scripted take
    private var script: KoiScript?
    /// Real seconds the take holds at its first instant before the clock
    /// starts, so a recording opens on settled frames.
    private var hold = 0.0
    private var nextBeat = 0
    private var move: (beat: KoiScript.Beat, path: [CGPoint], started: Double)?
    private var tapRelease: (point: CGPoint, at: Double)?
    private var shownFinger: CGPoint?
    private var fingerDownAt: Double?
    private var fingerUpAt: Double?
    /// A switch's finger lands on the control this long before the water
    /// starts to turn, and lifts as it does, the way a real tap would.
    static let pressLead = 0.15
    /// How long after a switch to Pool the floaters drop onto the water:
    /// once they've mostly faded in.
    static let landingDelay = 0.45
    private var pickerPressAt: Double?
    private var pressedBeat = -1
    private var pickerTarget: KoiPondMode = .pool

    /// What happened when, for laying sound under a recording.
    private var eventsURL: URL?
    private var events: [[String: Any]] = []
    private var lastBounce: [Int: Double] = [:]
    private var lastBump = -1.0
    private var floatSince = 0.0

    static let maxRipples = 96

    // MARK: Setup

    /// Applies `setup` if the pond hasn't started yet.
    func setUp(_ setup: Setup) {
        guard !isSetUp else { return }
        isSetUp = true
        koiCount = Self.clampKoi(setup.koi)
        jumpTo(mode: setup.mode)
        keepClear = setup.keepClear
        if let take = setup.take {
            pace = take.pace > 0.01 ? take.pace : 1
            hold = max(take.hold, 0)
            script = take.script?.choreography
            eventsURL = take.events
        }
    }

    func resize(to newSize: CGSize) {
        guard newSize.width > 1, newSize.height > 1 else { return }
        let first = size == .zero
        size = newSize
        if first { populate() } else { keepInside() }
    }

    func setMode(_ newMode: KoiPondMode) {
        guard newMode != mode else { return }
        mode = newMode
        landingAt = newMode == .pool ? clock + Self.landingDelay : nil
        // The pond's own waves don't carry on into the pool.
        if newMode == .pool { floatSince = clock }
        grabbed = nil
    }

    /// Changes the number of koi: new ones join where the pond puts them,
    /// and the last to join leave first.
    func setKoiCount(_ count: Int) {
        koiCount = Self.clampKoi(count)
        guard size != .zero else { return }
        if koi.count > koiCount { koi.removeLast(koi.count - koiCount) }
        while koi.count < koiCount { koi.append(makeKoi(koi.count)) }
    }

    private func jumpTo(mode newMode: KoiPondMode) {
        mode = newMode
        poolMix = newMode == .pool ? 1 : 0
        poolMixSpeed = 0
    }

    private static func clampKoi(_ count: Int) -> Int { max(0, min(count, 40)) }

    private func populate() {
        let w = size.width, h = size.height
        scale = min(max(min(w, h) / 400, 0.6), 1.4)
        koi = (0..<koiCount).map(makeKoi)

        // Lily pads round the pond, a few with flowers, none too close.
        pads = []
        var attempts = 0
        let padCount = max(4, Int((w * h) / 26_000))
        while pads.count < padCount && attempts < 400 {
            attempts += 1
            let radius = (24 + rng.next() * 30) * scale
            let edgeBias = rng.next() < 0.65
            var p = CGPoint(x: rng.next() * w, y: rng.next() * h)
            if edgeBias {
                // Favour the banks, as lilies do.
                if rng.next() < 0.5 { p.x = rng.next() < 0.5 ? rng.next() * w * 0.25 : w - rng.next() * w * 0.25 }
                else { p.y = rng.next() < 0.5 ? rng.next() * h * 0.2 : h - rng.next() * h * 0.2 }
            }
            p.x = min(max(p.x, radius * 0.6), w - radius * 0.6)
            p.y = min(max(p.y, radius * 0.6), h - radius * 0.6)
            if pads.contains(where: { hypot($0.center.x - p.x, $0.center.y - p.y) < ($0.radius + radius) * 0.95 }) { continue }
            let flower: LilyFlower? = rng.next() < 0.38
                ? LilyFlower(petals: 10 + Int(rng.next() * 5), radius: radius * (0.42 + rng.next() * 0.12),
                             pink: rng.next(), offset: CGVector(dx: (rng.next() - 0.5) * radius * 0.4, dy: (rng.next() - 0.5) * radius * 0.4),
                             turn: rng.next() * .pi)
                : nil
            pads.append(Pad(center: p, radius: radius, angle: rng.next() * 2 * .pi, spin: (rng.next() - 0.5) * 0.06,
                            notch: 0.32 + rng.next() * 0.16, tint: rng.next(), flower: flower))
        }

        floaties = [
            Floaty(kind: .tube, center: CGPoint(x: w * 0.36, y: h * 0.40), angle: 0.3, spin: 0.05, radius: 52 * scale),
            // The duck's art is drawn FloatyArt.duckScale up; so is its reach.
            Floaty(kind: .duck, center: CGPoint(x: w * 0.68, y: h * 0.62), angle: 1.75, spin: -0.03,
                   radius: 36 * FloatyArt.duckScale * scale),
        ]
    }

    private func makeKoi(_ index: Int) -> Koi {
        let w = size.width, h = size.height
        let look = KoiLook.varieties[index % KoiLook.varieties.count]
        let length = (78 + rng.next() * 30) * scale
        let start = CGPoint(x: w * (0.2 + 0.6 * rng.next()), y: h * (0.15 + 0.7 * rng.next()))
        let heading = rng.next() * 2 * .pi
        let segment = length / 13
        let spine = (0..<14).map { j in
            CGPoint(x: start.x - cos(heading) * segment * Double(j), y: start.y - sin(heading) * segment * Double(j))
        }
        return Koi(spine: spine, heading: heading, speed: 20, cruise: 20 + rng.next() * 12,
                   length: length, width: length * 0.15, swim: rng.next() * 6, fin: rng.next() * 6,
                   seed: rng.next() * 100, depth: 0.35 + 0.5 * rng.next(), look: look)
    }

    private func keepInside() {
        for i in koi.indices {
            koi[i].spine = koi[i].spine.map { CGPoint(x: min(max($0.x, 0), size.width), y: min(max($0.y, 0), size.height)) }
        }
    }

    // MARK: Touch

    func touchBegan(at point: CGPoint) {
        touchStart = (point, clock)
        finger = point
        padUnderFinger = poolMix < 0.5
            ? pads.indices.last(where: { hypot(pads[$0].center.x - point.x, pads[$0].center.y - point.y) < pads[$0].radius * 0.95 })
            : nil
        if poolMix > 0.5, let hit = floaties.indices.last(where: { hypot(floaties[$0].center.x - point.x, floaties[$0].center.y - point.y) < floaties[$0].radius * 1.1 }) {
            grabbed = hit
            grabOffset = CGVector(dx: floaties[hit].center.x - point.x, dy: floaties[hit].center.y - point.y)
            grabTrail = [(point, clock)]
            floaties[hit].velocity = .zero
            Haptics.impact(.soft)
        }
    }

    func touchMoved(to point: CGPoint) {
        if touchStart == nil { touchBegan(at: point) }
        finger = point
        if let g = grabbed {
            let r = floaties[g].radius * 0.9
            floaties[g].center = CGPoint(x: min(max(point.x + grabOffset.dx, r), size.width - r),
                                         y: min(max(point.y + grabOffset.dy, r), size.height - r))
            grabTrail.append((point, clock))
            grabTrail.removeAll { clock - $0.1 > 0.12 }
            return
        }
        // A finger that went down on a lily pad and moves takes the pad
        // with it, from where it's holding it.
        if grabbedPad == nil, let p = padUnderFinger, let start = touchStart,
           hypot(point.x - start.point.x, point.y - start.point.y) > 8 {
            grabbedPad = p
            padGrabOffset = CGVector(dx: pads[p].center.x - point.x, dy: pads[p].center.y - point.y)
            grabTrail = [(point, clock)]
            pads[p].velocity = .zero
            Haptics.impact(.soft)
        }
        if let p = grabbedPad {
            let r = pads[p].radius * 0.55
            pads[p].center = CGPoint(x: min(max(point.x + padGrabOffset.dx, r), size.width - r),
                                     y: min(max(point.y + padGrabOffset.dy, r), size.height - r))
            grabTrail.append((point, clock))
            grabTrail.removeAll { clock - $0.1 > 0.12 }
            // It pushes the water as it goes.
            if clock - lastPadRing > 0.1 {
                addRipple(at: pads[p].center, strength: 0.3)
                lastPadRing = clock
            }
            return
        }
        // Stirring: rings trail the finger.
        if let last = lastFingerRing, hypot(last.point.x - point.x, last.point.y - point.y) < 16, clock - last.time < 0.07 { return }
        addRipple(at: point, strength: 0.55)
        lastFingerRing = (point, clock)
    }

    func touchEnded(at point: CGPoint, velocity: CGSize? = nil) {
        defer { touchStart = nil; finger = nil; lastFingerRing = nil; grabbed = nil; grabbedPad = nil; padUnderFinger = nil }
        if let p = grabbedPad {
            // Let go, it carries on at the finger's pace (a pad is heavy in
            // the water, so not far), and settles.
            pads[p].velocity = releaseVelocity(velocity, cap: 900)
            addRipple(at: pads[p].center, strength: 0.35)
            return
        }
        if let g = grabbed {
            // Fling with the finger's speed as it let go; a finger that came
            // to rest first sets it down still.
            floaties[g].velocity = releaseVelocity(velocity, cap: 2_500)
            addRipple(at: floaties[g].center, strength: 0.6, source: g)
            return
        }
        guard let start = touchStart else { return }
        let moved = hypot(point.x - start.point.x, point.y - start.point.y)
        if moved < 10 && clock - start.time < 0.35 {
            addRipple(at: point, strength: 1.0)
            if poolMix < 0.5 { dropFood(at: point) }
            Haptics.impact(.light)
        }
    }

    /// The speed something let go of carries on at: the gesture's own
    /// velocity if the finger was still moving, else what the last tenth of
    /// a second of its trail says (nothing, if it had come to rest).
    private func releaseVelocity(_ velocity: CGSize?, cap: Double) -> CGVector {
        let recent = grabTrail.filter { clock - $0.1 < 0.1 }
        var v = CGVector.zero
        if recent.count > 1, let velocity {
            v = CGVector(dx: velocity.width, dy: velocity.height)
        } else if let first = recent.first, let last = recent.last, last.1 - first.1 > 0.01 {
            let dt = last.1 - first.1
            v = CGVector(dx: (last.0.x - first.0.x) / dt, dy: (last.0.y - first.0.y) / dt)
        }
        let speed = hypot(v.dx, v.dy)
        if speed > cap { v.dx *= cap / speed; v.dy *= cap / speed }
        return v
    }

    /// The system took the touch away (a back swipe, a call): forget it, so
    /// no phantom finger keeps the fish away or a floater held.
    private func cancelTouch() {
        guard touchStart != nil || grabbed != nil || grabbedPad != nil || finger != nil else { return }
        touchStart = nil; finger = nil; lastFingerRing = nil; grabbed = nil; grabbedPad = nil; padUnderFinger = nil
    }

    /// A pinch of food: a few pellets scattered where you tapped.
    private func dropFood(at point: CGPoint) {
        log("food", x: point.x)
        for _ in 0..<4 {
            let a = rng.next() * 2 * .pi, r = 4 + rng.next() * 16
            let inset = 40.0
            let p = CGPoint(x: min(max(point.x + cos(a) * r, inset), size.width - inset),
                            y: min(max(point.y + sin(a) * r, inset), size.height - inset))
            pellets.append(Pellet(point: p, drift: CGVector(dx: cos(a) * 6, dy: sin(a) * 6), born: clock))
            dropped += 1
        }
        if pellets.count > 16 { pellets.removeFirst(pellets.count - 16) }
    }

    private func addRipple(at point: CGPoint, strength: Double, source: Int = -1, small: Bool = false) {
        ripples.append(Ripple(x: point.x, y: point.y, born: clock, strength: strength, source: source, small: small))
        // Over the limit, the oldest tail swirl goes first, then the oldest ring.
        while ripples.count > Self.maxRipples {
            ripples.remove(at: ripples.firstIndex(where: \.small) ?? 0)
        }
    }

    // MARK: Stepping

    /// Advances to `date` in fixed small steps and returns what to draw.
    /// `fingerDown` is the gesture's own view of the touch: a touch the
    /// system cancelled stays released, and is forgotten after a moment.
    /// `setup` is applied first, if the pond hasn't started yet.
    func advance(to date: Date, fingerDown: Bool = true, setup: Setup? = nil) -> KoiPondFrame {
        if let setup { setUp(setup) }
        if epoch == nil { epoch = date.addingTimeInterval(hold) }
        // (A scripted take's touches never go through the gesture.)
        if fingerDown || touchStart == nil || script != nil {
            releasedSince = nil
        } else if releasedSince == nil {
            releasedSince = date
        } else if let since = releasedSince, date.timeIntervalSince(since) > 0.15 {
            cancelTouch()
            releasedSince = nil
        }
        var target = max(date.timeIntervalSince(epoch ?? date), 0) / pace
        // A scripted take keeps to whole 60ths of a second, so every frame of
        // the finished video can be an exact instant of the take.
        if script != nil { target = (target * 60).rounded(.down) / 60 }
        var remaining = min(max(target - clock, 0), 0.25)
        let step = 1.0 / 120
        while remaining > 1e-6 {
            let dt = min(step, remaining)
            tick(dt)
            remaining -= dt
        }
        clock = max(clock, target - 0.25)
        return snapshot()
    }

    private func tick(_ dt: Double) {
        clock += dt
        guard size.width > 1 else { return }
        if script != nil { runScript() }
        // A critically damped spring, so the water starts to turn gently
        // and settles in about a second, rather than lurching off at full
        // speed on the first frame (lily pads fading in over water that's
        // darkening too would pop).
        let goal = mode == .pool ? 1.0 : 0.0, omega = 5.5
        poolMixSpeed += (omega * omega * (goal - poolMix) - 2 * omega * poolMixSpeed) * dt
        poolMix = min(max(poolMix + poolMixSpeed * dt, 0), 1)
        if abs(goal - poolMix) < 0.002 && abs(poolMixSpeed) < 0.02 { poolMix = goal; poolMixSpeed = 0 }

        if let landing = landingAt, clock >= landing {
            for f in floaties { addRipple(at: f.center, strength: 1.3) }
            log("landing")
            landingAt = nil
            Haptics.impact(.medium)
        }

        stepKoi(dt)
        stepPads(dt)
        stepFloaties(dt)
        stepPellets(dt)
        ripples.removeAll { clock - $0.born > ($0.small ? 1.3 : 3.3) }
    }

    private func stepKoi(_ dt: Double) {
        let w = size.width, h = size.height
        let centre = CGPoint(x: w / 2, y: h / 2)
        let active = poolMix < 0.98
        for i in koi.indices {
            var k = koi[i]
            let head = k.spine[0]
            // Wander: a slow, fish-own drift of the heading, gentle enough
            // that a koi left alone cruises in long arcs round the pond.
            // (Twice this and it swam tight circles on the spot for ten
            // seconds at a time, so after feeding the whole school milled
            // in one knot where the food had been.)
            var turn = sin(k.seed + clock * 0.31) * 0.28 + sin(k.seed * 1.7 + clock * 0.53) * 0.18
            var targetSpeed = k.cruise
            var steer = CGVector.zero

            // The nearest pellet, if any is worth chasing.
            let food = active ? pellets.filter { clock - $0.born > 0.25 }
                .min(by: { hypot($0.point.x - head.x, $0.point.y - head.y) < hypot($1.point.x - head.x, $1.point.y - head.y) }) : nil
            let chasing = food != nil

            // Keep off the banks (less so with food in sight). A narrow
            // margin: a wide one penned a school against the bank, every
            // fish that turned out of it turned straight back in.
            let margin = min(w, h) * 0.1 + k.length * 0.25
            let edgeX = head.x < margin ? (margin - head.x) / margin : head.x > w - margin ? -(head.x - (w - margin)) / margin : 0
            let edgeY = head.y < margin ? (margin - head.y) / margin : head.y > h - margin ? -(head.y - (h - margin)) / margin : 0
            let bank = chasing ? 0.9 : 2.2
            steer.dx += edgeX * bank
            steer.dy += edgeY * bank
            if edgeX != 0 || edgeY != 0 {
                steer.dx += (centre.x - head.x) / max(w, 1) * 0.6
                steer.dy += (centre.y - head.y) / max(h, 1) * 0.6
            }

            // Give each other room: the head steers off the nearest part of
            // any other fish, its body and tail too, so they don't swim
            // through one another. Jostling over food they crowd in close;
            // cruising, or bolting from the same finger, they spread out
            // rather than heaping up as one tangled school.
            var crowd = CGVector.zero
            for j in koi.indices where j != i {
                var nearest = koi[j].spine[0], best = Double.infinity
                for s in stride(from: 0, to: koi[j].spine.count, by: 3) {
                    let p = koi[j].spine[s]
                    let d = hypot(head.x - p.x, head.y - p.y)
                    if d < best { best = d; nearest = p }
                }
                let reach = k.length * (chasing ? 0.6 : 0.85)
                if best < reach && best > 0.1 {
                    let push = (reach - best) / reach * (chasing ? 1.9 : 2.2)
                    steer.dx += (head.x - nearest.x) / best * push
                    steer.dy += (head.y - nearest.y) / best * push
                }
                // Where the others are, for leaving a crowd (below).
                let other = koi[j].spine[koi[j].spine.count / 3]
                let d = hypot(head.x - other.x, head.y - other.y)
                if d < k.length * 1.5 && d > 0.1 {
                    let weight = 1 - d / (k.length * 1.5)
                    crowd.dx += (head.x - other.x) / d * weight
                    crowd.dy += (head.y - other.y) / d * weight
                }
            }
            // Fed, and in a crowd: make for open water, a little quicker,
            // so a school that gathered to feed drifts apart.
            if !chasing, hypot(crowd.dx, crowd.dy) > 0.15 {
                let away = hypot(crowd.dx, crowd.dy)
                steer.dx += crowd.dx / away * min(away, 1.5) * 1.2
                steer.dy += crowd.dy / away * min(away, 1.5) * 1.2
                targetSpeed = max(targetSpeed, k.cruise + 14 * min(away, 1.5))
            }

            // Food: the nearest pellet pulls hard, and they hurry, easing up
            // as they close in or when it's off to the side, so they turn
            // onto it rather than circling it.
            if let food {
                let dx = food.point.x - head.x, dy = food.point.y - head.y
                let d = hypot(dx, dy)
                steer.dx += dx / max(d, 1) * 2.6
                steer.dy += dy / max(d, 1) * 2.6
                var off = atan2(dy, dx) - k.heading
                off = abs(atan2(sin(off), cos(off)))
                let near = min(1, d / 90)
                targetSpeed = 18 + 40 * near * max(0.25, cos(min(off, .pi / 2)))
            }

            // A finger in the water: dart away.
            var fleeing = false
            if let finger {
                let dx = head.x - finger.x, dy = head.y - finger.y
                let d = hypot(dx, dy)
                if d < 130 {
                    fleeing = true
                    let fear = (130 - d) / 130
                    steer.dx += dx / max(d, 1) * fear * 4
                    steer.dy += dy / max(d, 1) * fear * 4
                    targetSpeed = max(targetSpeed, 70 + 60 * fear)
                }
            }

            if hypot(steer.dx, steer.dy) > 0.05 {
                let want = atan2(steer.dy, steer.dx)
                var diff = want - k.heading
                diff = atan2(sin(diff), cos(diff))
                turn += diff * min(3.2, 0.8 + hypot(steer.dx, steer.dy) * 1.4)
            }
            // No tighter a circle than about half a body length cruising;
            // snapping at food, a quarter, or a pellet beside the fish sits
            // inside its turning circle and it swims rings round it. The
            // body can't curl however hard the head turns (see below).
            let tightest = k.length * (chasing ? 0.25 : fleeing ? 0.4 : 0.55)
            let maxTurn = min(1.4 + k.speed / 60, max(k.speed, 8) / tightest)
            k.heading += min(max(turn, -maxTurn), maxTurn) * dt
            k.speed += (targetSpeed - k.speed) * min(1, dt * (targetSpeed > k.speed ? 2.4 : 0.8))

            // Swim: the head leads and the body follows like a rope, except
            // that no joint bends past `joint`: on a hard turn the body
            // swings round with the head, the tail skidding wide, rather
            // than tracing the head's path and curling into a C.
            var newHead = CGPoint(x: head.x + cos(k.heading) * k.speed * dt, y: head.y + sin(k.heading) * k.speed * dt)
            newHead.x = min(max(newHead.x, -k.length * 0.2), w + k.length * 0.2)
            newHead.y = min(max(newHead.y, -k.length * 0.2), h + k.length * 0.2)
            k.spine[0] = newHead
            let segment = k.length / Double(k.spine.count - 1)
            let joint = 0.11
            var ahead = k.heading
            for j in 1..<k.spine.count {
                let a = k.spine[j - 1], b = k.spine[j]
                let along = atan2(a.y - b.y, a.x - b.x)
                let bend = min(max(atan2(sin(along - ahead), cos(along - ahead)), -joint), joint)
                ahead += bend
                k.spine[j] = CGPoint(x: a.x - cos(ahead) * segment, y: a.y - sin(ahead) * segment)
            }
            let stroke = floor(k.swim / .pi)
            k.swim += dt * 2 * .pi * (0.8 + k.speed / 38)
            // Each sweep of the tail sheds a little swirl at the surface, off
            // to one side and then the other; the nearer the top and the
            // faster the fish, the stronger. Together they trail behind it
            // the way a real koi's wake does: soft and uneven, not a V.
            if floor(k.swim / .pi) != stroke, poolMix <= 0.3, k.speed > 8 {
                let tail = k.spine[k.spine.count - 1], before = k.spine[k.spine.count - 2]
                let along = CGVector(dx: tail.x - before.x, dy: tail.y - before.y)
                let length = max(hypot(along.dx, along.dy), 0.001)
                let side = (Int(floor(k.swim / .pi)) % 2 == 0 ? 1.0 : -1.0) * k.width * 0.6
                let at = CGPoint(x: tail.x - along.dy / length * side, y: tail.y + along.dx / length * side)
                let jitter = 0.75 + 0.5 * (0.5 + 0.5 * sin(clock * 12.9898 + k.seed * 78.233))
                addRipple(at: at, strength: 1.8 * min(k.speed / 35, 1.6) * (1 - k.depth * 0.55) * jitter, small: true)
            }
            k.fin += dt * 2 * .pi * (0.55 + k.speed / 90)
            k.surfacing = max(0, k.surfacing - dt * 0.8)

            // Eating, once a pellet has landed: one dropped on a fish's head
            // is seen on the water before it goes.
            if active, let hit = pellets.firstIndex(where: { clock - $0.born > 0.3 && hypot($0.point.x - newHead.x, $0.point.y - newHead.y) < k.width * 1.2 + 4 }) {
                pellets.remove(at: hit)
                eaten += 1
                k.surfacing = 1
                // A small ring: a strong one magnifies the fish's own head
                // into a disc as it spreads over it.
                addRipple(at: newHead, strength: 0.25)
                log("gulp", x: newHead.x)
            }
            // A koi near the top now and then nudges the surface.
            // While they can't be seen, each koi's next ring is put off by
            // its own amount, so they don't all ring at once when the pond
            // comes back.
            if poolMix > 0.3 { k.lastRing = clock + k.seed.truncatingRemainder(dividingBy: 1.4) }
            // Now and then one comes near enough the top to break it.
            if poolMix <= 0.3 && clock - k.lastRing > 2.4 + k.depth * 2 && k.speed > 22 {
                let tail = k.spine[8]
                addRipple(at: tail, strength: 0.14 * (1 - k.depth * 0.5))
                log("ring", x: tail.x, value: 0.14 * (1 - k.depth * 0.5))
                k.lastRing = clock + rng.next() * 0.8
            }
            koi[i] = k
        }
    }

    private func stepPads(_ dt: Double) {
        // Out of sight while it's a pool: they wait where they were.
        guard poolMix < 0.98 else { return }
        let w = size.width, h = size.height
        // A slow current that turns over the minutes.
        let current = CGVector(dx: cos(clock * 0.05) * 1.6, dy: sin(clock * 0.037) * 1.2)
        let koiSeen = poolMix < 0.5
        for i in pads.indices where i != grabbedPad {
            var p = pads[i]
            var force = current
            // Pads keep apart.
            for j in pads.indices where j != i {
                let dx = p.center.x - pads[j].center.x, dy = p.center.y - pads[j].center.y
                let d = hypot(dx, dy), reach = (p.radius + pads[j].radius) * 0.96
                if d < reach && d > 0.1 {
                    force.dx += dx / d * (reach - d) * 6
                    force.dy += dy / d * (reach - d) * 6
                }
            }
            // Ripples nudge them.
            for r in ripples where !r.small {
                let age = clock - r.born
                let dx = p.center.x - r.x, dy = p.center.y - r.y
                let d = hypot(dx, dy)
                let front = age * 72
                if abs(d - front) < 18 && d > 1 {
                    force.dx += dx / d * r.strength * 34 * exp(-age)
                    force.dy += dy / d * r.strength * 34 * exp(-age)
                }
            }
            // Koi swimming under a pad lift and shove it as they pass, and
            // set it turning.
            if koiSeen {
                for k in koi {
                    let head = k.spine[0]
                    let dx = head.x - p.center.x, dy = head.y - p.center.y
                    guard hypot(dx, dy) < p.radius * 0.9 else { continue }
                    let shove = min(k.speed, 80) * (1 - k.depth * 0.5)
                    force.dx += cos(k.heading) * shove * 0.9
                    force.dy += sin(k.heading) * shove * 0.9
                    p.turn += (dx * sin(k.heading) - dy * cos(k.heading)) / max(p.radius, 1) * shove * 0.0009
                }
            }
            // A finger pushes them aside (one holding a pad pushes with it).
            if let finger, grabbedPad == nil, i != padUnderFinger {
                let dx = p.center.x - finger.x, dy = p.center.y - finger.y
                let d = hypot(dx, dy)
                if d < p.radius + 20 && d > 0.1 {
                    force.dx += dx / d * 220
                    force.dy += dy / d * 220
                }
            }
            // Banks.
            let r = p.radius * 0.55
            if p.center.x < r { force.dx += (r - p.center.x) * 3 }
            if p.center.x > w - r { force.dx -= (p.center.x - (w - r)) * 3 }
            if p.center.y < r { force.dy += (r - p.center.y) * 3 }
            if p.center.y > h - r { force.dy -= (p.center.y - (h - r)) * 3 }

            p.velocity.dx = (p.velocity.dx + force.dx * dt) * (1 - min(1, dt * 1.6))
            p.velocity.dy = (p.velocity.dy + force.dy * dt) * (1 - min(1, dt * 1.6))
            p.center.x += p.velocity.dx * dt
            p.center.y += p.velocity.dy * dt
            p.turn *= 1 - min(1, dt * 1.5)
            p.angle += (p.spin + p.turn) * dt
            pads[i] = p
        }
    }

    private func stepFloaties(_ dt: Double) {
        // Out of the water while it's a pond: they wait where they were.
        guard poolMix > 0 else { return }
        let w = size.width, h = size.height
        for i in floaties.indices where i != grabbed {
            var f = floaties[i]
            // A lazy drift, and the walls bounce them back.
            let drift = CGVector(dx: cos(clock * 0.21 + Double(i) * 2) * 3, dy: sin(clock * 0.17 + Double(i)) * 3)
            f.velocity.dx += drift.dx * dt
            f.velocity.dy += drift.dy * dt
            for r in ripples where r.source != i && r.born >= floatSince && !r.small {
                let age = clock - r.born
                let dx = f.center.x - r.x, dy = f.center.y - r.y
                let d = hypot(dx, dy)
                if abs(d - age * 72) < 18 && d > 1 {
                    f.velocity.dx += dx / d * r.strength * 30 * exp(-age) * dt * 4
                    f.velocity.dy += dy / d * r.strength * 30 * exp(-age) * dt * 4
                }
            }
            f.velocity.dx *= 1 - min(1, dt * 0.8)
            f.velocity.dy *= 1 - min(1, dt * 0.8)
            easeOutOfKeepClear(&f, dt)
            f.center.x += f.velocity.dx * dt
            f.center.y += f.velocity.dy * dt
            let r = f.radius * 0.9
            let before = hypot(f.velocity.dx, f.velocity.dy)
            var hit = false
            if f.center.x < r { f.center.x = r; f.velocity.dx = abs(f.velocity.dx) * 0.6; hit = true }
            if f.center.x > w - r { f.center.x = w - r; f.velocity.dx = -abs(f.velocity.dx) * 0.6; hit = true }
            if f.center.y < r { f.center.y = r; f.velocity.dy = abs(f.velocity.dy) * 0.6; hit = true }
            if f.center.y > h - r { f.center.y = h - r; f.velocity.dy = -abs(f.velocity.dy) * 0.6; hit = true }
            if hit && before > 90 && clock - (lastBounce[i] ?? -1) > 0.25 && poolMix > 0.5 {
                lastBounce[i] = clock
                addRipple(at: f.center, strength: min(0.9, before / 700), source: i)
                log("bounce", x: f.center.x, value: before, kind: f.kind == .duck ? "duck" : "tube")
            }
            f.spin += (sin(clock * 0.3 + Double(i)) * 0.08 - f.spin) * dt * 0.5
            f.angle += (f.spin + hypot(f.velocity.dx, f.velocity.dy) * 0.002) * dt
            floaties[i] = f
        }
        separateFloaties()
        // Moving floaters leave rings behind them.
        if poolMix > 0.5 {
            for i in floaties.indices {
                let v = hypot(floaties[i].velocity.dx, floaties[i].velocity.dy)
                let dragged = grabbed == i
                if (v > 25 || dragged) && clock - floaties[i].lastRing > 0.12 {
                    addRipple(at: floaties[i].center, strength: min(0.7, 0.2 + v / 400), source: i)
                    floaties[i].lastRing = clock
                }
            }
        }
        // While held, a floater follows the finger; track its speed for wakes.
        if let g = grabbed {
            let recent = grabTrail.filter { clock - $0.1 < 0.1 }
            if let first = recent.first, let last = recent.last, last.1 - first.1 > 0.01 {
                let dt = last.1 - first.1
                floaties[g].velocity = CGVector(dx: (last.0.x - first.0.x) / dt, dy: (last.0.y - first.0.y) / dt)
            } else {
                floaties[g].velocity = .zero
            }
            // A duck towed through the water swings round to face its way:
            // hardly at all while it's barely moving (no whipping round on
            // the spot), keeping up with the turns once it's going.
            let v = floaties[g].velocity, speed = hypot(v.dx, v.dy)
            if floaties[g].kind == .duck, speed > 1 {
                let turn = atan2(v.dy, v.dx) - floaties[g].angle
                floaties[g].angle += atan2(sin(turn), cos(turn)) * min(1, dt * 10 * min(1, speed / 150))
            }
        }
        for i in floaties.indices {
            let v = hypot(floaties[i].velocity.dx, floaties[i].velocity.dy)
            floaties[i].wake += (min(v / 220, 1) - floaties[i].wake) * min(1, dt * 3)
        }
    }

    /// A floater in a kept-clear band is pushed back out on a critically
    /// damped spring: no bounce, no snap, however it got there.
    private func easeOutOfKeepClear(_ f: inout Floaty, _ dt: Double) {
        let r = f.radius * 0.9, k = 300.0, c = 2 * k.squareRoot()
        func push(_ depth: Double, _ v: inout CGFloat, outward: Double) {
            guard depth > 0 else { return }
            v += (outward * depth * k - c * v) * dt
        }
        push(keepClear.top + r - f.center.y, &f.velocity.dy, outward: 1)
        push(f.center.y - (size.height - keepClear.bottom - r), &f.velocity.dy, outward: -1)
        push(keepClear.leading + r - f.center.x, &f.velocity.dx, outward: 1)
        push(f.center.x - (size.width - keepClear.trailing - r), &f.velocity.dx, outward: -1)
    }

    /// Floaters don't pass through each other. An overlap is pushed apart at
    /// once (all of it onto the one a finger isn't holding), and they bounce
    /// off each other, keeping half the speed they met at.
    private func separateFloaties() {
        for i in floaties.indices {
            for j in floaties.indices where j > i {
                let dx = floaties[j].center.x - floaties[i].center.x
                let dy = floaties[j].center.y - floaties[i].center.y
                let d = hypot(dx, dy), reach = floaties[i].radius + floaties[j].radius
                guard d < reach, d > 0.01 else { continue }
                let nx = dx / d, ny = dy / d, overlap = reach - d
                let (si, sj): (Double, Double) = grabbed == i ? (0, 1) : grabbed == j ? (1, 0) : (0.5, 0.5)
                floaties[i].center.x -= nx * overlap * si
                floaties[i].center.y -= ny * overlap * si
                floaties[j].center.x += nx * overlap * sj
                floaties[j].center.y += ny * overlap * sj
                let closing = (floaties[i].velocity.dx - floaties[j].velocity.dx) * nx
                    + (floaties[i].velocity.dy - floaties[j].velocity.dy) * ny
                guard closing > 0 else { continue }
                // Meeting a held one is like meeting a wall that moves: the
                // other is shoved along at its speed. Two free ones share
                // the bounce.
                let kick = closing * (si == 0 || sj == 0 ? 1.2 : 0.75)
                if si > 0 { floaties[i].velocity.dx -= nx * kick; floaties[i].velocity.dy -= ny * kick }
                if sj > 0 { floaties[j].velocity.dx += nx * kick; floaties[j].velocity.dy += ny * kick }
                if closing > 60 && clock - lastBump > 0.25 && poolMix > 0.5 {
                    lastBump = clock
                    log("bump", x: (floaties[i].center.x + floaties[j].center.x) / 2, value: closing)
                }
            }
        }
    }

    private func stepPellets(_ dt: Double) {
        for i in pellets.indices {
            pellets[i].point.x = min(max(pellets[i].point.x + pellets[i].drift.dx * dt, 40), size.width - 40)
            pellets[i].point.y = min(max(pellets[i].point.y + pellets[i].drift.dy * dt, 40), size.height - 40)
            pellets[i].drift.dx *= 1 - min(1, dt * 0.6)
            pellets[i].drift.dy *= 1 - min(1, dt * 0.6)
        }
        pellets.removeAll { clock - $0.born > 40 }
        if poolMix > 0.5 { pellets.removeAll() }
    }

    // MARK: Snapshot

    /// The surface height the shader would compute here, from rings only:
    /// enough to bob things floating on it.
    private func surfaceHeight(at p: CGPoint) -> Double {
        var h = 0.0
        for r in ripples where !r.small {
            let age = clock - r.born
            let d = hypot(p.x - r.x, p.y - r.y)
            let x = d - age * 72
            guard abs(x) < 60 else { continue }
            h += exp(-(x / 20) * (x / 20)) * exp(-age * 1.15) * r.strength / (1 + d * 0.012) * sin(x * 0.42)
        }
        return h
    }

    private func snapshot() -> KoiPondFrame {
        var frame = KoiPondFrame()
        frame.time = clock
        frame.poolMix = poolMix
        frame.size = size

        var flat: [Float] = []
        flat.reserveCapacity(ripples.count * 4)
        // Ages, not birth times: the shader's clock wraps, ages don't.
        // A tail swirl goes over with its strength negated, so the shader
        // can give it its own size and fade.
        for r in ripples { flat += [Float(r.x), Float(r.y), Float(clock - r.born), Float(r.small ? -r.strength : r.strength)] }
        frame.ripples = flat.isEmpty ? [0, 0, 100, 0] : flat

        var movers: [Float] = []
        // Through a switch, what's leaving is gone before the mix is halfway
        // and what's arriving only comes in after it, so the pond and the
        // pool are hardly ever seen through each other.
        let koiPresence = 1 - Curves.smoothstep(0.12, 0.55, poolMix)
        let floatPresence = Curves.smoothstep(0.45, 0.88, poolMix)
        for k in koi where koiPresence > 0.02 {
            let speed = min(k.speed / 45, 1) * (1 - k.depth * 0.4) * koiPresence
            // Negative: a swimmer under the surface (a swell, no V).
            movers += [Float(k.spine[0].x), Float(k.spine[0].y), Float(k.heading), Float(-speed)]
        }
        if floatPresence > 0.02 {
            for f in floaties {
                movers += [Float(f.center.x), Float(f.center.y), Float(atan2(f.velocity.dy, f.velocity.dx)),
                           Float(f.wake * floatPresence)]
            }
        }
        frame.movers = movers.isEmpty ? [0, 0, 0, 0] : movers

        frame.koi = koi.map { k in
            KoiSnapshot(spine: k.spine, width: k.width, swim: k.swim, fin: k.fin,
                        depth: max(0, k.depth - k.surfacing * 0.5), opacity: koiPresence, look: k.look)
        }
        let padPresence = koiPresence
        frame.pads = padPresence > 0.01 ? pads.map { p in
            LilyPadSnapshot(center: p.center, radius: p.radius, angle: p.angle, notch: p.notch, tint: p.tint,
                            flower: p.flower, bob: surfaceHeight(at: p.center), opacity: padPresence)
        } : []
        let landing = landingAt.map { max(0, ($0 - clock) / Self.landingDelay) } ?? 0
        frame.floaties = floatPresence > 0.01 ? floaties.map { f in
            FloatySnapshot(kind: f.kind, center: f.center, angle: f.angle, scale: scale * (1 + landing * 0.2),
                           bob: surfaceHeight(at: f.center), opacity: floatPresence)
        } : []
        frame.pellets = pellets.map(\.point)

        if script != nil {
            frame.touch = shownFinger
            if let down = fingerDownAt {
                let pressIn = min(max((clock - down) / 0.08, 0), 1)
                let lift = fingerUpAt.map { min(max((clock - $0) / 0.22, 0), 1) } ?? 0
                frame.touchPress = pressIn * (1 - lift)
            }
            if let down = pickerPressAt {
                // Pressed in like the finger on the water, lifted as the
                // mode changes, gone a moment later.
                let pressIn = min(max((clock - down) / 0.08, 0), 1)
                let lift = min(max((clock - down - Self.pressLead) / 0.22, 0), 1)
                if lift < 1 { frame.modeTap = pressIn * (1 - lift) }
            }
            frame.modeTarget = pickerTarget
        }

        frame.census = KoiPondFrame.Census(
            koi: koi.count,
            foodDropped: dropped,
            foodEaten: eaten,
            foodInWater: pellets.count,
            rings: ripples.filter { !$0.small && clock - $0.born < 1.5 }.count
        )
        return frame
    }

    // MARK: Running a script

    /// Plays the take's beats through the same touch handling a finger
    /// uses, so the take shows exactly what a person would get.
    private func runScript() {
        guard let script else { return }
        let w = size.width, h = size.height
        func at(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * w, y: p.y * h) }

        // A tap lifts a moment after it lands.
        if let release = tapRelease, clock >= release.at {
            touchEnded(at: release.point)
            fingerUpAt = clock
            tapRelease = nil
        }

        // A stroke or carry in progress follows its path.
        if let current = move {
            let duration: Double
            switch current.beat.move {
            case .stroke(_, let d): duration = d
            case .carry(_, _, let d, _): duration = d
            case .drag(_, _, let d, _): duration = d
            default: duration = 0
            }
            let u = min((clock - current.started) / max(duration, 0.01), 1)
            // A carry that ends in a fling is still moving when it lets go;
            // anything else is set down gently.
            var flung = false
            if case .carry(_, _, _, let release) = current.beat.move { flung = hypot(release.dx, release.dy) > 1 }
            if case .drag(_, _, _, let release) = current.beat.move { flung = hypot(release.dx, release.dy) > 1 }
            let point = Curves.point(along: current.path, at: flung ? Curves.easeIn(u) : Curves.easeInOut(u))
            touchMoved(to: point)
            shownFinger = point
            if u >= 1 {
                var velocity: CGSize?
                if case .carry(let kind, _, _, let release) = current.beat.move {
                    velocity = CGSize(width: release.dx, height: release.dy)
                    log("release", x: point.x, value: hypot(release.dx, release.dy), kind: kind == .duck ? "duck" : "tube")
                } else if case .drag(_, _, _, let release) = current.beat.move {
                    velocity = CGSize(width: release.dx, height: release.dy)
                    log("release", x: point.x, value: hypot(release.dx, release.dy), kind: "pad")
                } else {
                    log("lift", x: point.x)
                }
                touchEnded(at: point, velocity: velocity)
                fingerUpAt = clock
                move = nil
            }
        }

        // A switch coming up: the finger lands on its segment first.
        if nextBeat < script.beats.count, pressedBeat != nextBeat,
           case .mode(let target) = script.beats[nextBeat].move,
           clock >= script.beats[nextBeat].at - Self.pressLead {
            pressedBeat = nextBeat
            pickerPressAt = clock
            pickerTarget = target
            log("press", x: (target == .pool ? 0.75 : 0.25) * size.width)
        }

        while nextBeat < script.beats.count, clock >= script.beats[nextBeat].at {
            let beat = script.beats[nextBeat]
            nextBeat += 1
            switch beat.move {
            case .tap(let p):
                let point = at(p)
                touchBegan(at: point)
                tapRelease = (point, clock + 0.07)
                shownFinger = point
                fingerDownAt = clock; fingerUpAt = nil
                log("tap", x: point.x)
            case .stroke(let path, let duration):
                let points = path.map(at)
                touchBegan(at: points[0])
                move = (beat, points, clock)
                shownFinger = points[0]
                fingerDownAt = clock; fingerUpAt = nil
                log("stroke", x: points[0].x, value: duration)
            case .carry(let kind, let path, _, _):
                guard let index = floaties.firstIndex(where: { $0.kind == kind }) else { continue }
                // The path is where the floater goes; the finger holds the
                // float by its ring (not the hole in it), the duck by its back.
                let grip = kind == .tube ? CGVector(dx: 0, dy: -floaties[index].radius * 0.62) : .zero
                func held(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + grip.dx, y: p.y + grip.dy) }
                let start = held(floaties[index].center)
                touchBegan(at: start)
                move = (beat, [start] + path.map { held(at($0)) }, clock)
                shownFinger = start
                fingerDownAt = clock; fingerUpAt = nil
                log("grab", x: start.x, kind: kind == .duck ? "duck" : "tube")
            case .drag(let near, let path, _, _):
                let n = at(near)
                guard let index = pads.indices.min(by: { hypot(pads[$0].center.x - n.x, pads[$0].center.y - n.y)
                                                        < hypot(pads[$1].center.x - n.x, pads[$1].center.y - n.y) }) else { continue }
                // The finger goes down on the pad and the pad follows it.
                let start = pads[index].center
                touchBegan(at: start)
                move = (beat, [start] + path.map(at), clock)
                shownFinger = start
                fingerDownAt = clock; fingerUpAt = nil
                log("grab", x: start.x, kind: "pad")
            case .mode(let target):
                pickerTarget = target
                setMode(target)
                log("mode", value: target == .pool ? 1 : 0)
            }
        }
    }

    // MARK: The event log

    private func log(_ kind: String, x: Double = 0, value: Double = 0, kind subject: String = "") {
        guard let eventsURL else { return }
        events.append(["t": clock, "event": kind, "x": x / max(size.width, 1), "value": value, "of": subject])
        if let data = try? JSONSerialization.data(withJSONObject: events, options: []) {
            try? data.write(to: eventsURL)
        }
    }
}
