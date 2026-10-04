//
//  TakeTests.swift
//  KoiPondTests
//
//  The recording pipeline's contract with the pond: a scripted take's clock
//  steps in whole sixtieths (so a 60 fps video lands every frame on an exact
//  instant), a paced clock runs exactly that many times slower, a hold
//  keeps the first instant, and the same take plays out the same every
//  time. Plus the choreography itself: in order, inside the take, inside
//  the pond, and ending in the water it opened on so a video loops.
//
//  The world runs headless here, stepped with made-up dates; nothing is
//  drawn. What it looks like is checked on iPhone by the demo's UI tests.
//

import SwiftUI
import Testing
@_spi(Recording) @testable import KoiPond

@MainActor
struct TakeTests {

    private let size = CGSize(width: 440, height: 956)
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    private func world(_ take: KoiPondTake?, mode: KoiPondMode = .pond, koi: Int = 7) -> KoiPondWorld {
        let world = KoiPondWorld()
        world.setUp(.init(mode: mode, koi: koi, keepClear: EdgeInsets(), take: take))
        world.resize(to: size)
        return world
    }

    // MARK: The clock

    @Test func aScriptedClockStepsInWholeSixtieths() {
        let pond = world(KoiPondTake(script: .pond, pace: 8))
        // Frames arriving at uneven real times, as they do under load.
        var real = 0.0
        for i in 0..<400 {
            real += 0.011 + 0.009 * Double(i % 3)
            let time = pond.advance(to: start.addingTimeInterval(real)).time
            let sixtieths = time * 60
            #expect(abs(sixtieths - sixtieths.rounded()) < 1e-6, "\(time) s is between frames")
        }
    }

    @Test func pacingSlowsTheClock() {
        let pond = world(KoiPondTake(pace: 4))
        var time = 0.0
        for i in 0...120 { time = pond.advance(to: start.addingTimeInterval(Double(i) / 60)).time }
        // Two real seconds, four times slower.
        #expect(abs(time - 0.5) < 1e-9)
    }

    @Test func aHoldKeepsTheFirstInstant() {
        let pond = world(KoiPondTake(script: .pond, hold: 1))
        for real in [0.0, 0.4, 0.8, 1.0] {
            #expect(pond.advance(to: start.addingTimeInterval(real)).time == 0)
        }
        var time = 0.0
        for i in 1...30 { time = pond.advance(to: start.addingTimeInterval(1 + Double(i) / 60)).time }
        #expect(abs(time - 0.5) < 1e-9)
    }

    @Test func theSameTakePlaysOutTheSameEveryTime() {
        let first = world(KoiPondTake(script: .pond)), second = world(KoiPondTake(script: .pond))
        var a = KoiPondFrame(), b = KoiPondFrame()
        for i in 0...(60 * 6) {
            a = first.advance(to: start.addingTimeInterval(Double(i) / 60))
            b = second.advance(to: start.addingTimeInterval(Double(i) / 60))
        }
        #expect(a.time == b.time)
        #expect(a.koi.map(\.spine) == b.koi.map(\.spine))
        #expect(a.pads.map(\.center) == b.pads.map(\.center))
        #expect(a.ripples == b.ripples)
        // By six seconds the pond take has pushed a pad and fed the koi twice.
        #expect(a.foodDropped == 8)
    }

    // MARK: The koi

    @Test func theKoiCountFollowsChangesWithinLimits() {
        let pond = world(nil, koi: 7)
        #expect(pond.advance(to: start).koiCount == 7)
        pond.setKoiCount(3)
        #expect(pond.advance(to: start).koiCount == 3)
        pond.setKoiCount(55)
        #expect(pond.advance(to: start).koiCount == 40)
        pond.setKoiCount(-2)
        #expect(pond.advance(to: start).koiCount == 0)
    }

    // MARK: The choreography

    @Test(arguments: KoiPondTake.Script.allCases)
    func beatsAreInOrderInsideTheTakeAndThePond(_ script: KoiPondTake.Script) {
        let take = script.choreography
        let times = take.beats.map(\.at)
        #expect(times == times.sorted())
        for beat in take.beats {
            var points: [CGPoint] = []
            var ends = beat.at
            switch beat.move {
            case .tap(let p): points = [p]
            case .stroke(let path, let duration): points = path; ends += duration
            case .carry(_, let path, let duration, _): points = path; ends += duration
            case .drag(let near, let path, let duration, _): points = [near] + path; ends += duration
            case .mode: break
            }
            #expect(beat.at > 0)
            #expect(ends < take.length, "a move runs past the end of the take")
            #expect(points.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) }, "a move leaves the pond")
        }
    }

    @Test(arguments: KoiPondTake.Script.allCases)
    func eachTakeEndsInTheWaterItOpensOn(_ script: KoiPondTake.Script) {
        var water = script.startMode
        for beat in script.choreography.beats {
            if case .mode(let next) = beat.move {
                #expect(next != water, "a switch to the water it's already in")
                water = next
            }
        }
        #expect(water == script.startMode)
    }

    @Test func theHeroOpensOnThePool() {
        #expect(KoiPondTake.Script.hero.startMode == .pool)
        #expect(KoiPondTake.Script.hero.length == 17.4)
        #expect(KoiPondTake.Script.pond.startMode == .pond)
    }
}
