//
//  KoiPondDemoApp.swift
//  KoiPondDemo
//
//  The demo: a koi pond filling the screen, and Pond | Pool at the bottom.
//  Tap to feed the koi, drag to stir the water or push a lily pad aside;
//  in the pool, grab the duck or the float and fling it. See DemoConfig for
//  the launch switches the UI tests and the recording script use.
//

import SwiftUI

@main
struct KoiPondDemoApp: App {
    private let config = DemoConfig()

    var body: some Scene {
        WindowGroup {
            DemoView(config: config)
        }
    }
}
