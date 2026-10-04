//
//  KoiPondUITests.swift
//  KoiPondDemoUITests
//
//  End to end on iPhone: launches the demo and plays with the pond the way
//  a person would. Tap the water and food lands and the koi eat it; drag
//  through it and the surface ripples; switch to Pool with the control,
//  grab the rubber duck and drag it across; drag a lily pad aside.
//
//  Nothing is stubbed. The demo publishes what's in the water as an
//  invisible "koiPond.status" text (KOIPOND_PROBE=1), and the package puts
//  accessibility handles over the duck, the float and the lily pads, so the
//  tests can find them where they are. Screenshots land in
//  TEST_RUNNER_KOI_OUT when it is set.
//

import XCTest

final class KoiPondUITests: XCTestCase {

    private var outDir: String? { ProcessInfo.processInfo.environment["KOI_OUT"] }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Opens the demo on the pond and waits until the water is drawn.
    @MainActor
    private func openPond(koi: Int? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KOIPOND_PROBE"] = "1"
        if let koi { app.launchEnvironment["KOIPOND_COUNT"] = String(koi) }
        app.launch()
        XCTAssertTrue(app.staticTexts["koiPond.status"].waitForExistence(timeout: 60), "the pond never appeared")
        waitForWater()
        return app
    }

    @MainActor
    func testTappingFeedsTheKoi() throws {
        let app = openPond()
        let status = app.staticTexts["koiPond.status"]
        XCTAssertTrue(status.label.hasPrefix("Koi pond, 7 koi, 0 food, 0 dropped, 0 eaten"), status.label)
        shot("koi-0-pond")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42)).tap()
        shot("koi-1-food")
        XCTAssertTrue(wait(for: status, contains: "4 dropped", timeout: 5), "the tap didn't scatter food: \(status.label)")

        // The koi come for it and eat every pellet.
        XCTAssertTrue(wait(for: status, contains: "4 eaten", timeout: 40), "the koi never ate: \(status.label)")
        shot("koi-2-eaten")
        print("[koi-e2e] after feeding: \(status.label)")
    }

    /// An empty pond (no koi swimming through the frame), so what changes
    /// along a finger's stroke is the water itself.
    @MainActor
    func testStirringRipplesTheWater() throws {
        let app = openPond(koi: 0)
        let status = app.staticTexts["koiPond.status"]
        Thread.sleep(forTimeInterval: 1.5)
        let stroke = CGRect(x: 0.05, y: 0.5, width: 0.9, height: 0.14)    // where the finger goes
        let far = CGRect(x: 0.05, y: 0.12, width: 0.9, height: 0.14)       // well out of the rings' reach
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.57))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.57))

        let calm = XCUIScreen.main.screenshot()
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .fast, thenHoldForDuration: 0)
        let stirred = XCUIScreen.main.screenshot()
        let rings = status.label
        attach(calm, "koi-3-calm")
        attach(stirred, "koi-4-stirred")

        // Light drifts over the whole pond the same way; only the stroke's
        // band also has rings spreading through it.
        let near = difference(calm, stirred, band: stroke)
        let away = difference(calm, stirred, band: far)

        // The control: once the rings have died out (3.3 s), the same two
        // bands left alone change by about the same amount, so the check
        // below is telling rings from drift and not one band from another.
        Thread.sleep(forTimeInterval: 4)
        let still = XCUIScreen.main.screenshot()
        Thread.sleep(forTimeInterval: 1)
        let stillLater = XCUIScreen.main.screenshot()
        let nearStill = difference(still, stillLater, band: stroke)
        let awayStill = difference(still, stillLater, band: far)
        print("[koi-e2e] change along the stroke: \(near), far from it: \(away); \(rings). "
              + "Left alone: \(nearStill) and \(awayStill)")
        XCTAssertLessThan(nearStill, awayStill * 1.25 + 1, "the stroke's band changes on its own; this can't tell rings from drift")
        XCTAssertGreaterThan(near, away * 1.5 + 1, "the water didn't ripple where it was stirred")
    }

    @MainActor
    func testDuckCanBeDraggedAcrossThePool() throws {
        let app = openPond()
        app.buttons["Pool"].tap()
        let status = app.staticTexts["koiPond.status"]
        XCTAssertTrue(wait(for: status, label: "Pool with a rubber duck and a pool float", timeout: 5), "no pool: \(status.label)")
        let duck = app.descendants(matching: .any)["koiPond.duck"]
        XCTAssertTrue(duck.waitForExistence(timeout: 5), "no rubber duck")
        Thread.sleep(forTimeInterval: 1.2)
        shot("koi-5-pool")

        let size = app.frame.size
        let before = centre(duck)
        let grab = app.coordinate(withNormalizedOffset: CGVector(dx: before.x / size.width, dy: before.y / size.height))
        // Up the right side, clear of the float (left of centre): the two
        // collide, and a float shoved aside would push the duck off its mark.
        let target = CGPoint(x: size.width * 0.72, y: size.height * 0.28)
        let drop = app.coordinate(withNormalizedOffset: CGVector(dx: target.x / size.width, dy: target.y / size.height))
        grab.press(forDuration: 0.15, thenDragTo: drop, withVelocity: .slow, thenHoldForDuration: 0.3)
        Thread.sleep(forTimeInterval: 0.4)
        let after = centre(duck)
        shot("koi-6-duck-moved")
        print("[koi-e2e] duck \(before) -> \(after), aimed at \(target)")
        XCTAssertLessThan(hypot(after.x - target.x, after.y - target.y), 70, "the duck didn't follow the drag")
        XCTAssertGreaterThan(hypot(after.x - before.x, after.y - before.y), 100, "the duck didn't move")
    }

    /// A lily pad goes where it's dragged, pushing its neighbours aside.
    @MainActor
    func testLilyPadCanBeDraggedAside() throws {
        let app = openPond(koi: 0)
        let pads = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'koiPond.pad.'"))
        XCTAssertTrue(pads.firstMatch.waitForExistence(timeout: 5), "no lily pads")
        Thread.sleep(forTimeInterval: 1.0)
        // The pad nearest the middle, clear of the control and the banks.
        let size = app.frame.size
        let middle = CGPoint(x: size.width / 2, y: size.height / 2)
        let pad = try XCTUnwrap(pads.allElementsBoundByIndex.min {
            hypot(centre($0).x - middle.x, centre($0).y - middle.y) < hypot(centre($1).x - middle.x, centre($1).y - middle.y)
        })
        let id = pad.identifier
        let before = centre(pad)
        let target = CGPoint(x: before.x + (before.x < middle.x ? 140 : -140), y: before.y + 60)
        let grab = app.coordinate(withNormalizedOffset: CGVector(dx: before.x / size.width, dy: before.y / size.height))
        let drop = app.coordinate(withNormalizedOffset: CGVector(dx: target.x / size.width, dy: target.y / size.height))
        grab.press(forDuration: 0.15, thenDragTo: drop, withVelocity: .slow, thenHoldForDuration: 0.3)
        Thread.sleep(forTimeInterval: 0.4)
        let after = centre(app.descendants(matching: .any)[id])
        shot("koi-7-pad-moved")
        print("[koi-e2e] \(id) \(before) -> \(after), aimed at \(target)")
        XCTAssertLessThan(hypot(after.x - target.x, after.y - target.y), 50, "the pad didn't follow the drag")
    }

    // MARK: - Helpers

    /// Where a handle is: the middle of its frame, in screen points.
    @MainActor
    private func centre(_ element: XCUIElement) -> CGPoint {
        let frame = element.frame
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    /// Waits for the water to be drawn. The first time the app runs, the
    /// water shader's pipeline can take half a minute to build on a busy
    /// machine, and the floor is black until it has.
    @MainActor
    private func waitForWater(timeout: TimeInterval = 90) {
        let deadline = Date().addingTimeInterval(timeout)
        var black = 1.0
        while Date() < deadline {
            black = blackShare(XCUIScreen.main.screenshot())
            if black < 0.05 { return }
            Thread.sleep(forTimeInterval: 1)
        }
        XCTFail("the water was never drawn: \(Int(black * 100))% of the screen still black")
    }

    /// The share of the screen that is black.
    private func blackShare(_ screenshot: XCUIScreenshot) -> Double {
        guard let image = screenshot.image.cgImage, let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return 1 }
        let step = image.bitsPerPixel / 8
        var black = 0, total = 0
        for y in Swift.stride(from: 0, to: image.height, by: 8) {
            for x in Swift.stride(from: 0, to: image.width, by: 8) {
                let p = bytes + y * image.bytesPerRow + x * step
                if max(p[0], p[1], p[2]) < 10 { black += 1 }
                total += 1
            }
        }
        return total > 0 ? Double(black) / Double(total) : 1
    }

    private func wait(for element: XCUIElement, label: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label BEGINSWITH %@", label)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }

    private func wait(for element: XCUIElement, contains text: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }

    @MainActor
    @discardableResult
    private func shot(_ name: String) -> XCUIScreenshot {
        let screenshot = XCUIScreen.main.screenshot()
        attach(screenshot, name)
        return screenshot
    }

    private func attach(_ screenshot: XCUIScreenshot, _ name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let outDir {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: outDir).appendingPathComponent("\(name).png"))
        }
    }

    /// Mean per-pixel change between two screenshots in a band given as
    /// fractions of the screen.
    private func difference(_ a: XCUIScreenshot, _ b: XCUIScreenshot, band: CGRect) -> Double {
        guard let ia = a.image.cgImage, let ib = b.image.cgImage else { return 0 }
        let rect = CGRect(x: band.minX * Double(ia.width), y: band.minY * Double(ia.height),
                          width: band.width * Double(ia.width), height: band.height * Double(ia.height)).integral
        guard let ca = ia.cropping(to: rect), let cb = ib.cropping(to: rect),
              let da = ca.dataProvider?.data, let db = cb.dataProvider?.data,
              let pa = CFDataGetBytePtr(da), let pb = CFDataGetBytePtr(db) else { return 0 }
        let step = ca.bitsPerPixel / 8
        var total = 0.0, count = 0
        for y in Swift.stride(from: 0, to: ca.height, by: 2) {
            for x in Swift.stride(from: 0, to: ca.width, by: 2) {
                let oa = y * ca.bytesPerRow + x * step, ob = y * cb.bytesPerRow + x * step
                for c in 0..<3 { total += abs(Double(pa[oa + c]) - Double(pb[ob + c])) }
                count += 3
            }
        }
        return count > 0 ? total / Double(count) : 0
    }
}
