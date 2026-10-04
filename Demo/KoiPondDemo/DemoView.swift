//
//  DemoView.swift
//  KoiPondDemo
//
//  The pond fills the screen, with a glass Pond | Pool control at the
//  bottom that drains it into a pool (a rubber duck, a striped float) and
//  fills it back up.
//
//  The control and everything else drawn over the water come from the
//  pond's overlay, built from the frame it hands over: the thumb slides
//  with the pond's own `poolMix`, so in a slowed-down recording the
//  control, the floor's crossfade and the fish all stay in step.
//

import SwiftUI
@_spi(Recording) import KoiPond

struct DemoView: View {
    let config: DemoConfig
    @State private var mode: KoiPondMode

    init(config: DemoConfig) {
        self.config = config
        _mode = State(initialValue: config.mode)
    }

    var body: some View {
        // The duck and the float keep out from under the Dynamic Island and
        // the control.
        KoiPond(mode: mode, koi: config.koi, keepClear: EdgeInsets(top: 54, leading: 0, bottom: 92, trailing: 0)) { pond in
            overlay(pond)
        }
        .koiPondTake(config.take)
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(config.scripted ? .hidden : .automatic)
        .preferredColorScheme(.dark)
    }

    private func overlay(_ pond: KoiPondFrame) -> some View {
        GeometryReader { geo in
            let barY = geo.size.height - 34 - 34
            ZStack(alignment: .topLeading) {
                Color.clear
                if !config.scripted {
                    Text(pond.poolMix < 0.5 ? "Tap to feed · drag to stir" : "Grab the duck or the float and fling it")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                        .fixedSize()
                        .position(x: geo.size.width / 2, y: barY - 40)
                        .allowsHitTesting(false)
                }
                ModePicker(mix: pond.poolMix, tap: pond.scriptedModeTap, target: pond.scriptedModeTarget) { mode = $0 }
                    .position(x: geo.size.width / 2, y: barY)
                if let touch = pond.scriptedTouch, pond.scriptedTouchPress > 0.005 {
                    TouchDot(press: pond.scriptedTouchPress)
                        .position(touch)
                }
                if config.stamp {
                    ClockStamp(clock: pond.time)
                }
                if config.probe {
                    // What's in the water, for the UI tests.
                    Text(status(pond))
                        .font(.system(size: 2))
                        .opacity(0.02)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("koiPond.status")
                }
            }
        }
    }

    private func status(_ pond: KoiPondFrame) -> String {
        pond.poolMix > 0.5
            ? "Pool with a rubber duck and a pool float, \(pond.ringCount) ripples"
            : "Koi pond, \(pond.koiCount) koi, \(pond.foodInWater) food, \(pond.foodDropped) dropped, "
                + "\(pond.foodEaten) eaten, \(pond.ringCount) ripples"
    }
}

extension KoiPondMode {
    var title: String { self == .pond ? "Pond" : "Pool" }
}

#Preview {
    DemoView(config: DemoConfig(environment: [:]))
}
