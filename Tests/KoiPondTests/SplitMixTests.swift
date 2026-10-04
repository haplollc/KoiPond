//
//  SplitMixTests.swift
//  KoiPondTests
//
//  The seeded generator every pond is laid out with. The koi, the lily pads
//  and the food all come from it, and the recorded takes reach for things
//  where they start (the pad nearest a point, the duck), so it has to give
//  the same numbers on every device, every run. Self-contained arithmetic,
//  so plain unit tests; the pond itself is exercised on iPhone by the demo
//  app's UI tests.
//

import Testing
@testable import KoiPond

struct SplitMixTests {

    @Test func givesTheReferenceSequence() {
        // SplitMix64 from 0xC0FFEE (the world's seed), worked out
        // independently in Python.
        var rng = SplitMix(seed: 0xC0FFEE)
        #expect(rng.next() == 0.7910475122192537)
        #expect(rng.next() == 0.9253594679308002)
        #expect(rng.next() == 0.5302517201356893)
    }

    @Test func theSameSeedGivesTheSameNumbers() {
        var a = SplitMix(seed: 0x51E7), b = SplitMix(seed: 0x51E7)
        let first = (0..<10_000).map { _ in a.next() }
        let second = (0..<10_000).map { _ in b.next() }
        #expect(first == second)
    }

    @Test func differentSeedsGiveDifferentNumbers() {
        var a = SplitMix(seed: 1), b = SplitMix(seed: 2)
        #expect((0..<8).map { _ in a.next() } != (0..<8).map { _ in b.next() })
    }

    @Test func staysBelowOneAndSpreadsEvenly() {
        var rng = SplitMix(seed: 7)
        let values = (0..<20_000).map { _ in rng.next() }
        #expect(values.allSatisfy { $0 >= 0 && $0 < 1 })
        let mean = values.reduce(0, +) / Double(values.count)
        #expect(abs(mean - 0.5) < 0.01)
        // Ten equal bins, each within a tenth of its share.
        var bins = [Int](repeating: 0, count: 10)
        for v in values { bins[Int(v * 10)] += 1 }
        #expect(bins.allSatisfy { abs($0 - 2_000) < 200 }, "\(bins)")
    }
}
