//
//  KoiPondTake.swift
//  KoiPond
//
//  What the demo's recordings and UI tests need, as SPI:
//
//      @_spi(Recording) import KoiPond
//
//  A take plays a scripted finger through the pond, on a clock that can run
//  several times slower than real time, so a busy machine still captures
//  every frame and the video can be sped back up with each one exactly where
//  it should be. A scripted clock steps in whole sixtieths of a second, so
//  every frame of a 60 fps video is an exact instant of the take.
//

import SwiftUI

/// A scripted, optionally slowed-down run of the pond, for recordings.
@_spi(Recording)
public struct KoiPondTake: Sendable, Equatable {
    /// The choreography a take's finger plays.
    public enum Script: String, CaseIterable, Sendable {
        /// Opens on the pool: the duck carried round, the float flung off the
        /// far wall, a tap; then the pond: a lily pad pushed across, two
        /// feeding taps, a stir; then back to the pool.
        case hero
        /// Just the pool: the duck carried round, the float flung, two taps.
        case pool
        /// Just the pond: a lily pad pushed across, two feeding taps, a stir.
        case pond

        /// How long the take runs, in seconds on the pond's clock.
        public var length: Double { choreography.length }

        /// The water the take opens on: show this mode when it starts.
        public var startMode: KoiPondMode { choreography.start }

        var choreography: KoiScript {
            switch self {
            case .hero: .hero
            case .pool: .pool
            case .pond: .pond
            }
        }
    }

    /// What the finger does; `nil` leaves the pond to real touches.
    public var script: Script?
    /// The pond's clock runs this many times slower than real time.
    public var pace: Double
    /// Real seconds the take holds its first instant before the clock runs,
    /// so a recording opens on settled frames.
    public var hold: Double
    /// A file to log what happened when, as JSON, for laying sound under a
    /// recording: taps, grabs, releases, gulps, bounces, mode changes.
    public var events: URL?

    public init(script: Script? = nil, pace: Double = 1, hold: Double = 0, events: URL? = nil) {
        self.script = script
        self.pace = pace > 0.01 ? pace : 1
        self.hold = max(hold, 0)
        self.events = events
    }
}

extension EnvironmentValues {
    @Entry var koiPondTake: KoiPondTake? = nil
}

@_spi(Recording)
extension View {
    /// Ponds in this view play `take`, from when they first appear.
    public func koiPondTake(_ take: KoiPondTake?) -> some View {
        environment(\.koiPondTake, take)
    }
}

@_spi(Recording)
extension KoiPondFrame {
    /// Where a take's finger is touching the water, to draw it there.
    public var scriptedTouch: CGPoint? { touch }

    /// How pressed that finger is: 0 lifted … 1 down.
    public var scriptedTouchPress: Double { touchPress }

    /// A take's finger on the mode control: how pressed (0…1) while it
    /// plays, `nil` otherwise. It lands a beat before the water starts to
    /// turn and lifts as it does.
    public var scriptedModeTap: Double? { modeTap }

    /// The mode that finger is choosing.
    public var scriptedModeTarget: KoiPondMode { modeTarget }

    /// Koi in the pond.
    public var koiCount: Int { census.koi }

    /// Pellets of food scattered so far (four a tap).
    public var foodDropped: Int { census.foodDropped }

    /// Pellets the koi have eaten so far.
    public var foodEaten: Int { census.foodEaten }

    /// Pellets still floating.
    public var foodInWater: Int { census.foodInWater }

    /// Rings spreading from taps, strokes, gulps and splashes, under 1.5 s
    /// old (the koi's tail swirls aren't counted).
    public var ringCount: Int { census.rings }
}
