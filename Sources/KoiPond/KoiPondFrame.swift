//
//  KoiPondFrame.swift
//  KoiPond
//
//  One frame of the pond: what the drawing and the water shader need, and
//  the little of it an overlay is shown.
//

import SwiftUI

/// What a pond is doing on one frame.
///
/// A pond hands one to its overlay on every frame, so whatever you draw over
/// the water moves in step with it: a control that slides as the water
/// changes, a caption that fades out with the koi.
///
/// ```swift
/// KoiPond(mode: mode) { pond in
///     Text("Pool")
///         .opacity(pond.poolMix)
/// }
/// ```
public struct KoiPondFrame: Sendable {
    /// Seconds on the pond's own clock, from when it first appeared.
    public internal(set) var time: Double = 0
    /// How far the water has turned from pond to pool: 0 is all pond, 1 all
    /// pool. When the mode changes it eases across in about a second.
    public internal(set) var poolMix: Double = 0
    /// The pond's size, in points.
    public internal(set) var size: CGSize = .zero

    // MARK: For the drawing and the shader

    /// x, y, age (s), strength per ripple (strength negative for a tail
    /// swirl). Never empty: the shader is handed one long-gone ring instead.
    var ripples: [Float] = [0, 0, 100, 0]
    /// x, y, heading, speed (0…1) per swimmer or floater (speed negative for
    /// a koi under the surface).
    var movers: [Float] = [0, 0, 0, 0]
    var koi: [KoiSnapshot] = []
    var pads: [LilyPadSnapshot] = []
    var floaties: [FloatySnapshot] = []
    var pellets: [CGPoint] = []

    // MARK: A scripted take (see KoiPondTake)

    /// Where the take's finger is on the water, and how pressed (0 lifted …
    /// 1 down).
    var touch: CGPoint?
    var touchPress = 0.0
    /// The take's finger on the mode control: how pressed, and on which
    /// segment.
    var modeTap: Double?
    var modeTarget = KoiPondMode.pool

    // MARK: Read-outs

    var census = Census()

    /// What's in the water, counted.
    struct Census: Sendable {
        var koi = 0
        var foodDropped = 0
        var foodEaten = 0
        var foodInWater = 0
        /// Rings from taps, strokes, gulps and splashes under 1.5 s old (not
        /// the koi's tail swirls).
        var rings = 0
    }
}

// MARK: - What gets drawn

struct KoiSnapshot: Sendable {
    var spine: [CGPoint]
    var width: Double
    var swim: Double
    var fin: Double
    var depth: Double
    var opacity: Double
    var look: KoiLook
}

struct LilyPadSnapshot: Sendable {
    var center: CGPoint
    var radius: Double
    var angle: Double
    var notch: Double
    var tint: Double
    var flower: LilyFlower?
    var bob: Double
    var opacity: Double
}

struct FloatySnapshot: Sendable {
    var kind: FloatyKind
    var center: CGPoint
    var angle: Double
    /// Drawing scale: the pond's size scale times any landing swell.
    var scale: Double
    var bob: Double
    var opacity: Double
}

/// The pool's two floaters.
enum FloatyKind: Sendable {
    case duck, tube
}

/// A water lily in bloom, sitting on a pad.
struct LilyFlower: Sendable {
    var petals: Int
    var radius: Double
    /// 0 white … 1 deep pink.
    var pink: Double
    var offset: CGVector
    var turn: Double
}
