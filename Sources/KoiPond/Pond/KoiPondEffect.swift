//
//  KoiPondEffect.swift
//  KoiPond
//
//  The pond laid over any content, which becomes its floor. On every frame
//  the world steps, then the floor and the koi over it are flattened into
//  one layer and the water shader (KoiPond.metal) bends and lights it; what
//  floats is drawn on top, then the caller's overlay. One drag gesture over
//  the whole pond feeds, stirs, drags and flings.
//

import SwiftUI

struct KoiPondEffect<Overlay: View>: ViewModifier {
    let mode: KoiPondMode
    let koi: Int
    let keepClear: EdgeInsets
    let overlay: (KoiPondFrame) -> Overlay

    @State private var world = KoiPondWorld()
    /// Whether a finger is down, as the system sees it: if a touch is taken
    /// away mid-drag, onEnded never comes, and this is how the pond knows.
    @GestureState private var fingerDown = false
    @Environment(\.koiPondTake) private var take

    func body(content: Content) -> some View {
        TimelineView(.animation) { timeline in
            let frame = world.advance(to: timeline.date, fingerDown: fingerDown,
                                      setup: .init(mode: mode, koi: koi, keepClear: keepClear, take: take))
            content
                .environment(\.koiPoolMix, frame.poolMix)
                .overlay { KoiPondUnderwater(frame: frame) }
                // One flat layer, so the water can sample all of it.
                .drawingGroup()
                .visualEffect { view, proxy in
                    view.layerEffect(KoiPondWater.shader(frame, size: proxy.size),
                                     maxSampleOffset: KoiPondWater.maxSampleOffset)
                }
                .overlay { KoiPondSurface(frame: frame) }
                .overlay { KoiPondHandles(frame: frame) }
                .overlay { overlay(frame) }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { world.resize(to: $0) }
        .onChange(of: mode) { _, newMode in world.setMode(newMode) }
        .onChange(of: koi) { _, count in world.setKoiCount(count) }
        .onChange(of: keepClear) { _, insets in world.keepClear = insets }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($fingerDown) { _, down, _ in down = true }
                .onChanged { world.touchMoved(to: $0.location) }
                .onEnded { world.touchEnded(at: $0.location, velocity: $0.velocity) }
        )
    }
}

/// The water shader and its arguments.
enum KoiPondWater {
    static let library = ShaderLibrary.bundle(.module)

    /// Refraction bends the floor by at most a few points; ring slopes peak
    /// around 2, times a depth of 9.
    static let maxSampleOffset = CGSize(width: 32, height: 32)

    static func shader(_ frame: KoiPondFrame, size: CGSize) -> Shader {
        Shader(function: ShaderFunction(library: library, name: "koiWater"), arguments: [
            .float2(Float(size.width), Float(size.height)),
            .float4(Float(frame.time.truncatingRemainder(dividingBy: 1000)), Float(frame.poolMix), 0, 0),
            .floatArray(frame.ripples),
            .floatArray(frame.movers),
        ])
    }
}

/// Invisible handles over the lily pads and the pool's floaters, so
/// VoiceOver (and UI tests) can find them where they are.
struct KoiPondHandles: View {
    let frame: KoiPondFrame

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(Array(frame.pads.enumerated()), id: \.offset) { i, pad in
                Color.clear
                    .frame(width: pad.radius * 2, height: pad.radius * 2)
                    .position(pad.center)
                    .accessibilityElement()
                    .accessibilityLabel(Text("Lily pad", bundle: .module))
                    .accessibilityIdentifier("koiPond.pad.\(i)")
            }
            ForEach(Array(frame.floaties.enumerated()), id: \.offset) { _, floaty in
                let r = (floaty.kind == .tube ? 52.0 : 34.0 * FloatyArt.duckScale) * floaty.scale
                Color.clear
                    .frame(width: r * 2, height: r * 2)
                    .position(floaty.center)
                    .accessibilityElement()
                    .accessibilityLabel(floaty.kind == .tube ? Text("Pool float", bundle: .module) : Text("Rubber duck", bundle: .module))
                    .accessibilityIdentifier(floaty.kind == .tube ? "koiPond.tube" : "koiPond.duck")
            }
        }
        .allowsHitTesting(false)
    }
}
