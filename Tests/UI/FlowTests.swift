import XCTest

final class FlowTests: XCTestCase {
    func testCoreJourneyAndScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["首页"].waitForExistence(timeout: 10))
        capture("01-home")
        app.buttons["open-chat"].tap()
        XCTAssertTrue(app.textFields["chat-input"].waitForExistence(timeout: 5) || app.textViews["chat-input"].exists)
        capture("02-chat")
        let input = app.textFields["chat-input"].exists ? app.textFields["chat-input"] : app.textViews["chat-input"]
        input.tap()
        input.typeText("Hello")
        app.buttons["send-chat"].tap()
        XCTAssertTrue(app.staticTexts["常曦 · 示例回复"].waitForExistence(timeout: 8))
        app.buttons["关闭"].firstMatch.tap()
        app.tabBars.buttons["健康"].tap()
        capture("03-health")
        app.segmentedControls.buttons["趋势"].tap()
        capture("04-trends")
        app.segmentedControls.buttons["报告"].tap()
        capture("05-reports")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "9月5日体检报告")).firstMatch.tap()
        capture("05b-report-detail")
        app.tabBars.buttons["服务"].tap()
        capture("06-services")
        app.tabBars.buttons["我的"].tap()
        capture("07-profile")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "常曦记忆")).firstMatch.tap()
        capture("08-memory")
        let confirm = app.buttons["确认"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        app.segmentedControls.buttons["已记住"].tap()
        XCTAssertTrue(app.staticTexts["症状自述"].exists)
        capture("09-memory-confirmed")
    }
    func testRecordAndServiceJourney() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.tabBars.buttons["健康"].tap()
        app.buttons["metric-血压"].tap()
        app.buttons["添加血压记录"].tap()
        let primary = app.textFields["reading-primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 5))
        primary.tap(); primary.typeText("123")
        app.textFields["reading-secondary"].tap(); app.textFields["reading-secondary"].typeText("77")
        app.buttons["save-reading"].tap()
        XCTAssertTrue(app.staticTexts["123/77"].waitForExistence(timeout: 5))
        capture("10-record-saved")
        app.tabBars.buttons["服务"].tap()
        app.buttons["service-帮预约"].tap()
        app.buttons["保存预约意向"].tap()
        XCTAssertTrue(app.staticTexts["尚未提交至医疗机构"].exists)
        capture("11-booking-saved")
        app.buttons["查看服务记录"].tap()
        app.buttons["取消意向"].firstMatch.tap()
        let cancelButtons = app.buttons.matching(NSPredicate(format: "label == %@", "取消意向"))
        cancelButtons.element(boundBy: cancelButtons.count - 1).tap()
        XCTAssertTrue(app.staticTexts["已取消本地意向"].waitForExistence(timeout: 5))
    }
    func testLargeTextAndLandscape() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--large-text"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["首页"].waitForExistence(timeout: 10))
        capture("12-large-text-home")
        app.tabBars.buttons["健康"].tap()
        capture("13-large-text-health")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.tabBars.buttons["健康"].exists)
        capture("14-landscape")
        XCUIDevice.shared.orientation = .portrait
    }
    private func capture(_ name: String) {
        // Accessibility updates precede the end of native tab/navigation transitions.
        Thread.sleep(forTimeInterval: 0.8)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
