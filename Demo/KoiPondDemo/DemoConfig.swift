//
//  DemoConfig.swift
//  KoiPondDemo
//
//  How the demo was launched. With none of these it is the interactive
//  demo: the pond fills the screen and Pond | Pool switches the water. The
//  UI tests and the recording script (Scripts/record.sh) set them with the
//  launch environment.
//
//    KOIPOND_MODE=pool       open on the pool
//    KOIPOND_COUNT=0         how many koi (default 7)
//    KOIPOND_PROBE=1         publish what's in the water for the UI tests
//                            (an invisible "koiPond.status" text)
//    KOIPOND_DEMO=1          play the scripted take, with a finger drawn
//                            where it touches
//    KOIPOND_SCRIPT=pool     …which take: pool, pond or hero (the default)
//    KOIPOND_PACE=8          run the pond's clock eight times slower, for
//                            recording on a busy machine
//    KOIPOND_HOLD=6          hold the take's first instant for six real
//                            seconds, so a recording opens on settled frames
//    KOIPOND_EVENTS=<file>   log what happened when, as JSON, for sound
//    KOIPOND_STAMP=1         stamp the pond's clock in the top-left corner
//                            (on in a take; Scripts/sync.py reads it)
//

import Foundation
@_spi(Recording) import KoiPond

struct DemoConfig {
    /// The water the page opens on.
    let mode: KoiPondMode
    let koi: Int
    let probe: Bool
    /// The scripted take or the slowed-down clock, when recording.
    let take: KoiPondTake?
    let stamp: Bool

    init(environment env: [String: String] = ProcessInfo.processInfo.environment) {
        let scripted = env["KOIPOND_DEMO"] == "1"
        let script = scripted ? KoiPondTake.Script(rawValue: env["KOIPOND_SCRIPT"] ?? "hero") ?? .hero : nil
        let pace = env["KOIPOND_PACE"].flatMap(Double.init) ?? 1
        if scripted || pace != 1 {
            take = KoiPondTake(script: script, pace: pace,
                               hold: scripted ? env["KOIPOND_HOLD"].flatMap(Double.init) ?? 0 : 0,
                               events: scripted ? env["KOIPOND_EVENTS"].map { URL(fileURLWithPath: $0) } : nil)
        } else {
            take = nil
        }
        // A take opens on the water its script starts in.
        mode = env["KOIPOND_MODE"].flatMap(KoiPondMode.init(rawValue:)) ?? script?.startMode ?? .pond
        koi = env["KOIPOND_COUNT"].flatMap(Int.init) ?? 7
        probe = env["KOIPOND_PROBE"] == "1"
        stamp = scripted || env["KOIPOND_STAMP"] == "1"
    }

    /// Whether a scripted finger is playing (no hint, no home indicator).
    var scripted: Bool { take?.script != nil }
}
