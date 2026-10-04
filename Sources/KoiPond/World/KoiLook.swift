//
//  KoiLook.swift
//  KoiPond
//
//  How each koi is coloured: the classic varieties, from Kohaku to Asagi.
//

import SwiftUI

/// A koi's colouring: a base and the blotches on its back, placed along the
/// body (0 nose … 1 tail) and across it (-1 … 1).
struct KoiLook: Sendable {
    struct Blotch: Sendable {
        var along: Double, across: Double
        /// Shares of the body's length and width.
        var length: Double, breadth: Double
        var turn: Double
        var colour: Color
    }

    var name: String
    var base: Color
    var fins: Color
    var blotches: [Blotch]
    var sheen: Double

    static let white = Color(red: 0.97, green: 0.95, blue: 0.91)
    static let red = Color(red: 0.90, green: 0.27, blue: 0.14)
    static let ink = Color(red: 0.07, green: 0.07, blue: 0.08)

    /// The varieties, given out to the koi in turn.
    static let varieties: [KoiLook] = [
        KoiLook(name: "Kohaku", base: white, fins: white, blotches: [
            Blotch(along: 0.12, across: 0.0, length: 0.18, breadth: 0.9, turn: 0.1, colour: red),
            Blotch(along: 0.36, across: 0.25, length: 0.22, breadth: 1.1, turn: -0.2, colour: red),
            Blotch(along: 0.62, across: -0.15, length: 0.16, breadth: 0.9, turn: 0.3, colour: red),
        ], sheen: 0.18),
        KoiLook(name: "Tancho", base: white, fins: white, blotches: [
            Blotch(along: 0.10, across: 0.0, length: 0.11, breadth: 0.72, turn: 0, colour: red),
        ], sheen: 0.18),
        KoiLook(name: "Ogon", base: Color(red: 0.98, green: 0.78, blue: 0.32), fins: Color(red: 1.0, green: 0.84, blue: 0.45),
                blotches: [], sheen: 0.38),
        KoiLook(name: "Sanke", base: white, fins: white, blotches: [
            Blotch(along: 0.14, across: -0.1, length: 0.16, breadth: 1.0, turn: 0.2, colour: red),
            Blotch(along: 0.42, across: 0.2, length: 0.24, breadth: 1.0, turn: -0.1, colour: red),
            Blotch(along: 0.30, across: -0.55, length: 0.07, breadth: 0.35, turn: 0.4, colour: ink),
            Blotch(along: 0.55, across: 0.5, length: 0.06, breadth: 0.32, turn: -0.3, colour: ink),
            Blotch(along: 0.70, across: -0.2, length: 0.05, breadth: 0.3, turn: 0.1, colour: ink),
        ], sheen: 0.16),
        KoiLook(name: "Kigoi", base: Color(red: 0.98, green: 0.52, blue: 0.16), fins: Color(red: 1.0, green: 0.62, blue: 0.3),
                blotches: [], sheen: 0.24),
        KoiLook(name: "Showa", base: ink, fins: Color(red: 0.2, green: 0.2, blue: 0.22), blotches: [
            Blotch(along: 0.16, across: 0.1, length: 0.2, breadth: 1.0, turn: 0.2, colour: red),
            Blotch(along: 0.45, across: -0.3, length: 0.2, breadth: 0.8, turn: -0.3, colour: white),
            Blotch(along: 0.60, across: 0.3, length: 0.16, breadth: 0.8, turn: 0.2, colour: red),
        ], sheen: 0.22),
        KoiLook(name: "Kohaku", base: white, fins: white, blotches: [
            Blotch(along: 0.22, across: -0.2, length: 0.30, breadth: 1.2, turn: 0.3, colour: red),
            Blotch(along: 0.58, across: 0.2, length: 0.2, breadth: 1.0, turn: -0.2, colour: red),
        ], sheen: 0.18),
        KoiLook(name: "Asagi", base: Color(red: 0.55, green: 0.66, blue: 0.78), fins: Color(red: 0.95, green: 0.52, blue: 0.3), blotches: [
            Blotch(along: 0.78, across: 0.6, length: 0.2, breadth: 0.5, turn: 0, colour: Color(red: 0.92, green: 0.45, blue: 0.25)),
            Blotch(along: 0.78, across: -0.6, length: 0.2, breadth: 0.5, turn: 0, colour: Color(red: 0.92, green: 0.45, blue: 0.25)),
        ], sheen: 0.2),
    ]
}
