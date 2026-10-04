import XCTest

/// Walks the guest flow end to end: garage, add a car by VIN, a demo drive, stop. With SHOTS_DIR set it also
/// saves a screenshot at each step (handy for eyeballing the UI without a person at the simulator).
final class FlowTests: XCTestCase {
    let app = XCUIApplication()

    private func shot(_ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["SHOTS_DIR"] else { return }
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    func testGuestFlow() throws {
        app.launch()
        let guest = app.buttons["Look around without an account"]
        if guest.waitForExistence(timeout: 15) { guest.tap() }

        XCTAssertTrue(app.buttons["Start drive"].waitForExistence(timeout: 10))
        shot("1-map")

        app.tabBars.buttons["Garage"].tap()
        XCTAssertTrue(app.staticTexts["Add your first car"].waitForExistence(timeout: 5))
        shot("2-garage-empty")

        app.buttons["Add car"].firstMatch.tap()
        let vin = app.textFields["17-character VIN"]
        XCTAssertTrue(vin.waitForExistence(timeout: 5))
        vin.tap()
        vin.typeText("1HGCM82633A004352")
        app.buttons["Look up"].tap()
        XCTAssertTrue(app.staticTexts["We found"].waitForExistence(timeout: 15), "VIN lookup should find the Accord")
        shot("3-vin-found")
        app.buttons["Add to garage"].tap()
        XCTAssertTrue(app.staticTexts["2003 Honda Accord"].waitForExistence(timeout: 5))
        shot("4-garage")

        // The car's card opens its screen, where the adapter is connected (or a demo drive started).
        app.staticTexts["2003 Honda Accord"].tap()
        XCTAssertTrue(app.staticTexts["OBD adapter"].waitForExistence(timeout: 5))
        shot("4b-car-detail")
        app.buttons["Connect adapter"].tap()
        XCTAssertTrue(app.staticTexts["Adapters nearby"].waitForExistence(timeout: 5) || app.staticTexts["Turn on Bluetooth in Settings to find your adapter."].exists || app.staticTexts["This device doesn't support Bluetooth."].exists)
        shot("5-connect")
        app.buttons["Cancel"].tap()
        app.buttons["Try a demo drive"].tap()
        // The map stays clean while driving: just a slim pill. The numbers are on the Live tab.
        app.tabBars.buttons["Map"].tap()
        XCTAssertTrue(app.staticTexts["Recording"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["RPM"].exists, "no live numbers over the map")
        shot("5b-map-recording")
        app.tabBars.buttons["Live"].tap()
        XCTAssertTrue(app.staticTexts["Car"].waitForExistence(timeout: 10), "the Live tab lists every reading")
        shot("6-live")
        XCTAssertTrue(app.buttons["Stop drive"].waitForExistence(timeout: 15))
        sleep(4)
        shot("6-driving")
        app.buttons["Stop drive"].tap()
        XCTAssertTrue(app.buttons["Start drive"].waitForExistence(timeout: 5))

        // The finished drive is listed under search, like Google Maps.
        app.staticTexts["Where to?"].tap()
        XCTAssertTrue(app.staticTexts["Recent drives"].waitForExistence(timeout: 5))
        shot("7-search-trips")

        // Tapping the drive shows it on the map for review.
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Honda Accord'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Top speed"].waitForExistence(timeout: 5))
        shot("8-review")
    }
}
