//
//  RogersMarketPlaceUITests.swift
//  RogersMarketPlaceUITests
//
//  Created by Navdeep Rana on 23/09/26.
//

import XCTest

final class RogersMarketPlaceUITests: XCTestCase {

    /// Browse online → relaunch offline → create → pending badge → relaunch online → synced.
    func test_createListingOffline_isPendingThenSyncsWhenBackOnline() {
        var app = launch()
        XCTAssertTrue(app.buttons["listing-card"].firstMatch.waitForExistence(timeout: 10))
        pause(1.5)

        app.terminate()
        app = launch(arguments: ["-simulateOffline"], reset: false)
        XCTAssertTrue(app.buttons["listing-card"].firstMatch.waitForExistence(timeout: 10), "Expected cached listings while offline")
        let status = app.staticTexts["sync-status"]
        XCTAssertTrue(status.label.contains("Offline"), "Unexpected status: \(status.label)")
        pause(1.5)

        app.buttons["create-listing-button"].tap()
        let title = app.textFields["form-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("Vintage record player")
        let description = app.descendants(matching: .any)["form-description"].firstMatch
        description.tap(); description.typeText("Works perfectly, comes with 10 records.")
        app.textFields["form-price"].tap(); app.textFields["form-price"].typeText("180")
        app.textFields["form-location"].tap(); app.textFields["form-location"].typeText("Toronto")
        pause(1)
        app.buttons["form-save"].tap()

        XCTAssertTrue(app.staticTexts["Vintage record player"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["sync-badge"].firstMatch.exists, "Expected a Pending badge while offline")
        XCTAssertTrue(app.staticTexts["sync-status"].label.contains("1 change"))
        pause(2)

        app.terminate()
        app = launch(reset: false)
        let predicate = NSPredicate(format: "label == %@", "All changes synced")
        expectation(for: predicate, evaluatedWith: app.staticTexts["sync-status"])
        waitForExpectations(timeout: 15)
        XCTAssertTrue(app.staticTexts["Vintage record player"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["sync-badge"].firstMatch.exists, "Expected the Pending badge to disappear after sync")
        pause(2)
    }

    // MARK: - Helpers

    private func launch(arguments: [String] = [], reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = (reset ? ["-resetState"] : []) + arguments
        app.launch()
        return app
    }

    private func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
}
