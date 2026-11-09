import XCTest

final class WidgetSetupUITests: XCTestCase {
    @MainActor
    func testManualWidgetModeChooserOpens() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-no-app-group", "--ui-testing-reset"]
        app.launch()
        XCUIDevice.shared.press(.home)
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        let icon = home.icons["Moment"]
        for _ in 0..<4 {
            if icon.exists && icon.isHittable { break }
            home.swipeLeft()
        }
        XCTAssertTrue(icon.waitForExistence(timeout: 10), home.debugDescription)
        icon.press(forDuration: 1.3)
        let editHome = home.buttons["Edit Home Screen"]
        XCTAssertTrue(editHome.waitForExistence(timeout: 5), home.debugDescription)
        editHome.tap()

        let edit = home.buttons["Edit"]
        if edit.waitForExistence(timeout: 3) { edit.tap() }
        let addWidget = home.buttons["Add Widget"]
        XCTAssertTrue(addWidget.waitForExistence(timeout: 5), home.debugDescription)
        addWidget.tap()

        let search = home.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), home.debugDescription)
        search.tap()
        search.typeText("Moment")
        let result = home.staticTexts["Moment"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10), home.debugDescription)
        result.tap()
        let addSelected = home.buttons["Add Widget"]
        XCTAssertTrue(addSelected.waitForExistence(timeout: 5), home.debugDescription)
        addSelected.tap()
        let done = home.buttons["Done"]
        if done.waitForExistence(timeout: 5) { done.tap() }

        let widget = home.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Укажите дату и время")).firstMatch
        XCTAssertTrue(widget.waitForExistence(timeout: 15), home.debugDescription)
        widget.press(forDuration: 1.3)
        let editWidget = home.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Edit", "Moment")
        ).firstMatch
        XCTAssertTrue(editWidget.waitForExistence(timeout: 5), home.debugDescription)
        editWidget.tap()

        let manual = home.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Вручную")).firstMatch
        XCTAssertTrue(manual.waitForExistence(timeout: 5), home.debugDescription)
        manual.tap()
        let fromApp = home.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Из приложения")).firstMatch
        XCTAssertTrue(fromApp.waitForExistence(timeout: 5), "The mode chooser must actually open. " + home.debugDescription)
        let chooser = XCTAttachment(screenshot: home.screenshot())
        chooser.name = "Native widget mode chooser"
        chooser.lifetime = .keepAlways
        add(chooser)

        let manualChoice = home.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Вручную")).firstMatch
        XCTAssertTrue(manualChoice.exists)
        manualChoice.tap()
        let date = home.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Дата и время")).firstMatch
        XCTAssertTrue(date.waitForExistence(timeout: 5), home.debugDescription)
        let fields = XCTAttachment(screenshot: home.screenshot())
        fields.name = "Native widget manual configuration"
        fields.lifetime = .keepAlways
        add(fields)
    }
}
