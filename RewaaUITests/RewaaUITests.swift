//
//  RewaaUITests.swift
//  RewaaUITests
//
//  Created by Linda on 17/04/2026.
//

import XCTest

final class RewaaUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTabBarDisplaysMainSections() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UI_TESTING")
        app.launch()

        XCTAssertTrue(app.staticTexts["Today's Routine"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Water Intake"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
