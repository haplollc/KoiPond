//
//  PublicAPITests.swift
//  KoiPondTests
//
//  The ways the README uses the package, written against the public API
//  alone (a plain import, not @testable): if the API and the docs drift
//  apart, this file stops compiling.
//

import SwiftUI
import Testing
import KoiPond

private struct PondScreen: View {
    @State private var mode = KoiPondMode.pond

    var body: some View {
        KoiPond(mode: mode) { pond in
            Button(pond.poolMix < 0.5 ? "Drain it" : "Fill it") {
                mode = mode == .pond ? .pool : .pond
            }
            .buttonStyle(.borderedProminent)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 40)
        }
        .ignoresSafeArea()
    }
}

private struct GardenPond: View {
    var body: some View {
        LinearGradient(colors: [.green, .teal], startPoint: .top, endPoint: .bottom)
            .koiPond()
    }
}

private struct CaptionedPond: View {
    let mode: KoiPondMode

    var body: some View {
        Color.indigo
            .koiPond(mode, koi: 12, keepClear: EdgeInsets(top: 60, leading: 0, bottom: 100, trailing: 0)) { pond in
                Text(pond.poolMix < 0.5 ? "Tap to feed" : "Fling the duck")
                    .opacity(pond.time > 1 ? 1 : pond.time)
                    .frame(width: pond.size.width)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
    }
}

@MainActor
struct PublicAPITests {
    @Test func theTwoWaters() {
        #expect(KoiPondMode.allCases == [.pond, .pool])
        #expect(KoiPondMode(rawValue: "pool") == .pool)
        #expect(KoiPondMode.pond.id == .pond)
    }

    @Test func everyWayInMakesAView() {
        _ = PondScreen()
        _ = GardenPond()
        _ = CaptionedPond(mode: .pool)
        _ = KoiPond()
        _ = KoiPond(mode: .pool, koi: 0, keepClear: EdgeInsets(top: 54, leading: 0, bottom: 92, trailing: 0))
    }
}
