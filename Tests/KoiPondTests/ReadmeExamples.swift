//
//  ReadmeExamples.swift
//  KoiPondTests
//
//  Every snippet in README.md, compiled against the package as it ships,
//  so the README can't drift from the API. Nothing here runs; the stand-ins
//  at the bottom play the parts of the reader's own app.
//

import SwiftUI
import KoiPond

// MARK: The whole integration

private struct WholeIntegration: View {
    var body: some View {
        MyView().koiPond()
    }
}

// MARK: Quick start

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

// MARK: Your own floor

private struct OwnFloor: View {
    var body: some View {
        VStack {
            Image("garden")
                .resizable()
                .scaledToFill()
                .koiPond()

            LinearGradient(colors: [.teal, .indigo], startPoint: .top, endPoint: .bottom)
                .koiPond(.pond, koi: 12)                 // any number from 0 to 40
        }
    }
}

// MARK: Drawing over the water

private struct OverTheWater: View {
    @State private var mode = KoiPondMode.pond

    var body: some View {
        MyFloor()
            .koiPond(mode, keepClear: EdgeInsets(top: 0, leading: 0, bottom: 90, trailing: 0)) { pond in
                ModePicker(selection: $mode, progress: pond.poolMix)   // slides as the water changes
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 32)
            }
    }
}

private func frameFields(_ pond: KoiPondFrame) -> (Double, Double, CGSize) {
    (pond.poolMix, pond.time, pond.size)
}

// MARK: Stand-ins for the reader's app

private struct MyView: View {
    var body: some View { Color.brown }
}

private struct MyFloor: View {
    var body: some View { Color.gray }
}

private struct ModePicker: View {
    @Binding var selection: KoiPondMode
    let progress: Double

    var body: some View {
        Picker("Water", selection: $selection) {
            ForEach(KoiPondMode.allCases) { Text($0.rawValue.capitalized).tag($0) }
        }
        .pickerStyle(.segmented)
        .opacity(0.6 + 0.4 * progress)
    }
}
