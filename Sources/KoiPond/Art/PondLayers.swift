//
//  PondLayers.swift
//  KoiPond
//
//  The two layers drawn each frame: what's under the water (the shadows on
//  the floor, then the koi), which the water bends, and what floats on it
//  (food, lily pads, the pool's floaters), drawn over the ripples.
//

import SwiftUI

// MARK: - Under the water: shadows, then the koi

/// Everything below the surface that moves: the shadows the floaters and
/// the fish cast on the floor, and the koi themselves. It sits inside the
/// water effect, so the ripples bend all of it.
struct KoiPondUnderwater: View {
    let frame: KoiPondFrame

    var body: some View {
        Canvas { context, _ in
            // Shadows on the floor: the sun is up and to the left, so they
            // fall down and to the right, further for things nearer the top.
            context.drawLayer { shadows in
                shadows.addFilter(.blur(radius: 5))
                for k in frame.koi where k.opacity > 0.01 {
                    let lift = 10 + 12 * (1 - k.depth)
                    var c = shadows
                    c.translateBy(x: lift * 0.55, y: lift)
                    c.opacity = 0.28 * k.opacity * (0.7 + 0.3 * (1 - k.depth))
                    KoiArt.fill(k, in: c, colour: .black)
                }
                for p in frame.pads where p.opacity > 0.01 {
                    var c = shadows
                    c.translateBy(x: 14, y: 22)
                    c.opacity = 0.32 * p.opacity
                    c.fill(LilyArt.padPath(p), with: .color(.black))
                }
                for f in frame.floaties where f.opacity > 0.01 {
                    var c = shadows
                    c.translateBy(x: 16 * f.scale, y: 26 * f.scale)
                    c.opacity = 0.30 * f.opacity
                    FloatyArt.shadow(f, in: c)
                }
                for pellet in frame.pellets {
                    shadows.fill(Path(ellipseIn: CGRect(x: pellet.x + 3, y: pellet.y + 6, width: 5, height: 5)),
                                 with: .color(.black.opacity(0.3)))
                }
            }
            for k in frame.koi where k.opacity > 0.01 {
                KoiArt.draw(k, in: context)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// What floats on the water, drawn over the ripples.
struct KoiPondSurface: View {
    let frame: KoiPondFrame

    var body: some View {
        Canvas { context, _ in
            for pellet in frame.pellets {
                let r = CGRect(x: pellet.x - 2.6, y: pellet.y - 2.6, width: 5.2, height: 5.2)
                context.fill(Path(ellipseIn: r), with: .color(Color(red: 0.55, green: 0.32, blue: 0.16)))
                context.fill(Path(ellipseIn: r.insetBy(dx: 1.4, dy: 1.4).offsetBy(dx: -0.6, dy: -0.6)),
                             with: .color(Color(red: 0.78, green: 0.55, blue: 0.32)))
            }
            for p in frame.pads where p.opacity > 0.01 {
                LilyArt.draw(p, in: context)
            }
            for f in frame.floaties where f.opacity > 0.01 {
                FloatyArt.draw(f, in: context)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
