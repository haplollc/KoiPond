//
//  KoiPond.swift
//  KoiPond
//
//  A koi pond for SwiftUI. `.koiPond()` turns any view into the floor of a
//  pond: koi glide over it, lily pads drift on top, and the water ripples
//  and refracts all of it, answering every fish that swims by. Tap to
//  scatter food and the koi come for it; drag through the water to stir it
//  and they dart away. In pool mode the koi drain out and a rubber duck and
//  a striped float drop in, to grab and fling.
//
//      MyView().koiPond()          // any view as the pond's floor
//      KoiPond(mode: .pool)        // the ready-made pond and pool
//

import SwiftUI

/// Which water the pond holds.
public enum KoiPondMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    /// A koi pond: koi, lily pads and water lilies over the floor. Tap to
    /// scatter food, drag through the water to stir it, drag a lily pad to
    /// push it aside.
    case pond
    /// A swimming pool: a rubber duck and a striped float on clear water.
    /// Grab either one and fling it; tap to send out a ripple.
    case pool

    public var id: Self { self }
}

extension View {
    /// Puts this view at the bottom of a koi pond that fills its frame.
    ///
    /// Koi glide over the view, lily pads drift on the surface, and the
    /// water ripples and refracts all of it. Tap to scatter food and the koi
    /// race for it; drag through the water and they dart away. Set `mode` to
    /// ``KoiPondMode/pool`` and the koi and pads fade out as a rubber duck
    /// and a pool float drop in; set it back and the pond returns.
    ///
    /// ```swift
    /// Image("garden")
    ///     .resizable()
    ///     .scaledToFill()
    ///     .koiPond()
    /// ```
    ///
    /// The view is flattened into one layer for the water to bend, so it has
    /// to be something SwiftUI draws itself: shapes, gradients, images, text,
    /// a `Canvas`. Views backed by UIKit (maps, text fields, video, web
    /// views) don't render inside it.
    ///
    /// The pond takes the touches in its frame to feed, stir, drag and
    /// fling, so put controls over the water, in the overlay (see
    /// `koiPond(_:koi:keepClear:overlay:)`), rather than in the floor.
    ///
    /// - Parameters:
    ///   - mode: Pond or pool. A change eases the water from one to the other
    ///     in about a second.
    ///   - koi: How many koi swim in the pond, from 0 to 40.
    ///   - keepClear: Bands along the edges that the pool's duck and float
    ///     stay out of, such as under a toolbar. One flung in is eased back
    ///     out.
    public func koiPond(
        _ mode: KoiPondMode = .pond,
        koi: Int = 7,
        keepClear: EdgeInsets = EdgeInsets()
    ) -> some View {
        modifier(KoiPondEffect(mode: mode, koi: koi, keepClear: keepClear) { _ in EmptyView() })
    }

    /// Puts this view at the bottom of a koi pond that fills its frame, with
    /// an overlay drawn over the water in step with the pond.
    ///
    /// The overlay sits on top of the water, out of the ripples, and is
    /// rebuilt on every frame of the pond with a ``KoiPondFrame``: build a
    /// control from ``KoiPondFrame/poolMix`` and it slides as the water
    /// changes, on the pond's own clock.
    ///
    /// ```swift
    /// MyFloor()
    ///     .koiPond(mode) { pond in
    ///         Text(pond.poolMix < 0.5 ? "Tap to feed" : "Fling the duck")
    ///             .frame(maxHeight: .infinity, alignment: .bottom)
    ///             .padding(.bottom, 40)
    ///     }
    /// ```
    ///
    /// See `koiPond(_:koi:keepClear:)` for what the floor can be.
    ///
    /// - Parameters:
    ///   - mode: Pond or pool. A change eases the water from one to the other
    ///     in about a second.
    ///   - koi: How many koi swim in the pond, from 0 to 40.
    ///   - keepClear: Bands along the edges that the pool's duck and float
    ///     stay out of, such as under your overlay's controls.
    ///   - overlay: What to draw over the water, given what the pond is doing.
    public func koiPond<Overlay: View>(
        _ mode: KoiPondMode = .pond,
        koi: Int = 7,
        keepClear: EdgeInsets = EdgeInsets(),
        @ViewBuilder overlay: @escaping (KoiPondFrame) -> Overlay
    ) -> some View {
        modifier(KoiPondEffect(mode: mode, koi: koi, keepClear: keepClear, overlay: overlay))
    }
}

/// The ready-made pond: a bed of pebbles under the koi and a tiled floor
/// under the pool, crossfading as the water changes.
///
/// ```swift
/// struct PondScreen: View {
///     @State private var mode = KoiPondMode.pond
///
///     var body: some View {
///         KoiPond(mode: mode) { pond in
///             Button(pond.poolMix < 0.5 ? "Drain it" : "Fill it") {
///                 mode = mode == .pond ? .pool : .pond
///             }
///             .buttonStyle(.borderedProminent)
///             .frame(maxHeight: .infinity, alignment: .bottom)
///             .padding(.bottom, 40)
///         }
///         .ignoresSafeArea()
///     }
/// }
/// ```
///
/// To put the koi over a floor of your own, use
/// `.koiPond(_:koi:keepClear:)` on it instead.
public struct KoiPond<Overlay: View>: View {
    private let mode: KoiPondMode
    private let koi: Int
    private let keepClear: EdgeInsets
    private let overlay: (KoiPondFrame) -> Overlay

    /// A pond with an overlay drawn over the water in step with it.
    ///
    /// - Parameters:
    ///   - mode: Pond or pool. A change eases the water from one to the other
    ///     in about a second.
    ///   - koi: How many koi swim in the pond, from 0 to 40.
    ///   - keepClear: Bands along the edges that the pool's duck and float
    ///     stay out of, such as under your overlay's controls.
    ///   - overlay: What to draw over the water, rebuilt on every frame of
    ///     the pond with what it is doing.
    public init(
        mode: KoiPondMode = .pond,
        koi: Int = 7,
        keepClear: EdgeInsets = EdgeInsets(),
        @ViewBuilder overlay: @escaping (KoiPondFrame) -> Overlay
    ) {
        self.mode = mode
        self.koi = koi
        self.keepClear = keepClear
        self.overlay = overlay
    }

    public var body: some View {
        KoiPondFloor()
            .modifier(KoiPondEffect(mode: mode, koi: koi, keepClear: keepClear, overlay: overlay))
    }
}

extension KoiPond where Overlay == EmptyView {
    /// A pond with nothing drawn over the water.
    ///
    /// - Parameters:
    ///   - mode: Pond or pool. A change eases the water from one to the other
    ///     in about a second.
    ///   - koi: How many koi swim in the pond, from 0 to 40.
    ///   - keepClear: Bands along the edges that the pool's duck and float
    ///     stay out of, such as under a toolbar.
    public init(mode: KoiPondMode = .pond, koi: Int = 7, keepClear: EdgeInsets = EdgeInsets()) {
        self.init(mode: mode, koi: koi, keepClear: keepClear) { _ in EmptyView() }
    }
}

#Preview("The pond") {
    KoiPond()
        .ignoresSafeArea()
}

#Preview("The pool") {
    KoiPond(mode: .pool)
        .ignoresSafeArea()
}

#Preview("Any view as the floor") {
    VStack(spacing: 14) {
        Image(systemName: "sun.max.fill")
            .font(.system(size: 84))
            .foregroundStyle(.yellow)
        Text("Hello, pond")
            .font(.largeTitle.bold())
            .foregroundStyle(.white)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(red: 0.16, green: 0.22, blue: 0.2))
    .koiPond()
}
