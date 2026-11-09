import XCTest

final class WidgetSetupUITests: XCTestCase {
    @MainActor
    func testManualWidgetModeChooserOpens() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-no-app-group", "--ui-testing-reset"]
        app.launch()
        XCUIDevice.shared.press(.home)
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        var visibleIcon: XCUIElement?
        for _ in 0..<4 {
            visibleIcon = home.icons.matching(identifier: "Moment").allElementsBoundByIndex.first {
                $0.frame.intersects(home.frame) && $0.isHittable
            }
            if visibleIcon != nil { break }
            home.swipeLeft()
        }
        let icon = try XCTUnwrap(visibleIcon, home.debugDescription)
        icon.press(forDuration: 1.3)
        let editHome = home.buttons["Edit Home Screen"]
        XCTAssertTrue(editHome.waitForExistence(timeout: 5), home.debugDescription)
        editHome.tap()

        let edit = home.buttons["Edit"]
        if edit.waitForExistence(timeout: 3) { edit.tap() }
        let addWidget = home.buttons["Add Widget"]
        XCTAssertTrue(addWidget.waitForExistence(timeout: 5), home.debugDescription)
        addWidget.tap()

        // SpringBoard incorrectly reports the offscreen App Library field as
        // hittable. The gallery field has its own stable label.
        let search = home.searchFields["Search Widgets"]
        XCTAssertTrue(search.waitForExistence(timeout: 5), home.debugDescription)
        search.tap()
        search.typeText("Moment")
        // A fresh simulator can present the system's QuickPath onboarding over
        // the results after the keyboard first appears.
        let keyboardTip = home.buttons["Continue"]
        if keyboardTip.waitForExistence(timeout: 3) { keyboardTip.tap() }
        let result = home.cells["Moment"]
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
            NSPredicate(format: "label == %@ OR (label BEGINSWITH %@ AND label CONTAINS %@)",
                        "Edit Widget", "Edit", "Moment")
        ).firstMatch
        XCTAssertTrue(editWidget.waitForExistence(timeout: 5), home.debugDescription)
        editWidget.tap()

        let manualRows = home.descendants(matching: .any).matching(NSPredicate(
            format: "label == %@ OR (label BEGINSWITH %@ AND label CONTAINS %@)",
            "Вручную", "Настройка", "Вручную"
        ))
        XCTAssertTrue(manualRows.firstMatch.waitForExistence(timeout: 5), home.debugDescription)
        let manual = try XCTUnwrap(manualRows.allElementsBoundByIndex.first(where: { $0.isHittable }), home.debugDescription)
        manual.tap()
        let fromApp = home.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Из приложения")).firstMatch
        XCTAssertTrue(fromApp.waitForExistence(timeout: 5), "The mode chooser must actually open. " + home.debugDescription)
        let chooser = XCTAttachment(screenshot: home.screenshot())
        chooser.name = "Native widget mode chooser"
        chooser.lifetime = .keepAlways
        add(chooser)

        let choices = home.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH %@ AND NOT label CONTAINS %@", "Вручную", "Вручную:"
        ))
        let manualChoice = try XCTUnwrap(choices.allElementsBoundByIndex.first(where: { $0.isHittable }), home.debugDescription)
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
