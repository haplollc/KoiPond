//
//  ModePicker.swift
//  KoiPondDemo
//
//  Pond | Pool in a glass capsule, drawn by hand rather than a segmented
//  Picker: its thumb sits where the water is, sliding as the pond drains
//  and fills, on the pond's clock (a system control animates on its own
//  clock, which a slowed-down recording would play back too fast). Plus the
//  scripted take's finger and the clock stamp a recording is timed by.
//

import SwiftUI
import KoiPond

struct ModePicker: View {
    /// 0 pond … 1 pool.
    let mix: Double
    /// A scripted finger on a segment: how pressed, 0…1.
    var tap: Double?
    var target: KoiPondMode = .pool
    let select: (KoiPondMode) -> Void

    private let width = 224.0, height = 40.0, inset = 4.0

    var body: some View {
        let segment = (width - inset * 2) / 2
        let thumb = Capsule()
            .frame(width: segment, height: height - inset * 2)
            .offset(x: inset + segment * mix)
        ZStack(alignment: .leading) {
            thumb
                .foregroundStyle(Color.white.opacity(0.92))
                .shadow(color: .black.opacity(0.22), radius: 6, y: 2)
            // White on the glass; dark wherever the thumb is, so a word
            // changes as the thumb slides across it rather than all at once
            // halfway.
            labels(Color.white.opacity(0.9))
            labels(Color.black.opacity(0.85), decorative: true)
                .mask(alignment: .leading) { thumb }
            if let tap {
                // The same touch as a finger on the water.
                TouchDot(press: tap)
                    .position(x: inset + segment * (target == .pool ? 1.5 : 0.5), y: height / 2)
            }
        }
        .frame(width: width, height: height)
        .modifier(GlassCapsule())
        // A soft shade under the glass. Liquid Glass turns light over bright
        // water, on its own clock, a beat after the water does; with this it
        // reads dark over the pool as over the pond, and white words hold.
        .background {
            Capsule()
                .fill(Color.black.opacity(0.32))
                .blur(radius: 5)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("koiPond.mode")
    }

    /// The two segments' words. Only the row on the glass is the control;
    /// the copy inside the thumb is paint, so it neither takes touches nor
    /// reaches VoiceOver.
    private func labels(_ color: Color, decorative: Bool = false) -> some View {
        let segment = (width - inset * 2) / 2
        return HStack(spacing: 0) {
            ForEach(KoiPondMode.allCases) { option in
                let on = option == .pool ? mix : 1 - mix
                let word = Text(option.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: segment, height: height)
                if decorative {
                    word.accessibilityHidden(true)
                } else {
                    // A plain Button: it takes its tap over the pond's own
                    // drag, like any control in the pond's overlay.
                    Button { select(option) } label: {
                        word.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on > 0.5 ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, inset)
        .allowsHitTesting(!decorative)
    }
}

/// Liquid Glass where there is some (iOS 26), a material before it.
private struct GlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
        }
    }
}

/// Where a scripted finger is touching: a soft white disc, like the
/// simulator's "show touches", pressing in as it lands.
struct TouchDot: View {
    let press: Double

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.24 * press))
            .overlay(Circle().stroke(Color.white.opacity(0.85 * press), lineWidth: 2))
            // A dark hairline just outside the ring, so a touch shows on the
            // bright pool as well as the dark pond.
            .overlay(Circle().stroke(Color.black.opacity(0.4 * press), lineWidth: 1.5).padding(-1.75))
            .shadow(color: .black.opacity(0.3 * press), radius: 5, y: 1.5)
            .frame(width: 44, height: 44)
            .scaleEffect(1.12 - 0.12 * press)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The pond's clock in 4 ms steps as a 4 x 4 grid of black-or-white 3 pt
/// cells in the top-left corner, where a device frame's rounded corner
/// hides it. Scripts/sync.py reads it back from a recording to time the
/// take, and Scripts/retime.py rebuilds the video at an exact 60 fps.
struct ClockStamp: View {
    let clock: Double

    var body: some View {
        let value = Int((max(clock, 0) * 250).rounded(.down)) & 0xFFFF
        Canvas { context, _ in
            context.fill(Path(CGRect(x: 0, y: 0, width: 12, height: 12)), with: .color(.white))
            for bit in 0..<16 where value & (1 << bit) != 0 {
                let cell = CGRect(x: Double(bit % 4) * 3, y: Double(bit / 4) * 3, width: 3, height: 3)
                context.fill(Path(cell), with: .color(.black))
            }
        }
        .frame(width: 12, height: 12)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
