import XCTest

final class EventCreationUITests: XCTestCase {
    @MainActor
    func testCreateEventAndRelaunchWithoutAppGroup() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-no-app-group", "--ui-testing-reset"]
        app.launch()

        XCTAssertFalse(app.alerts.firstMatch.exists, "Missing App Group must not show a blocking alert")
        let create = app.buttons["createEventButton"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        XCTAssertTrue(create.isEnabled)
        create.tap()

        let title = app.textFields["eventTitleField"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Sideload test event")
        let save = app.buttons["saveEventButton"]
        XCTAssertTrue(save.isEnabled)
        save.tap()

        let event = app.buttons["featuredEvent"]
        XCTAssertTrue(event.waitForExistence(timeout: 5))
        XCTAssertEqual(event.label, "Sideload test event")
        attachScreenshot(app, name: "Event saved without App Group")

        app.terminate()
        app.launchArguments = ["--ui-testing-no-app-group"]
        app.launch()
        XCTAssertTrue(event.waitForExistence(timeout: 10))
        XCTAssertEqual(event.label, "Sideload test event")
        XCTAssertFalse(app.alerts.firstMatch.exists)
        attachScreenshot(app, name: "Event persists after relaunch")

        // Check the second entry point (+) as well as the empty-state button.
        let add = app.buttons["addEventButton"]
        XCTAssertTrue(add.isEnabled)
        add.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
