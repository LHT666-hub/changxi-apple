import XCTest

final class FlowTests: XCTestCase {
    func testCoreJourneyAndScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["首页"].firstMatch.waitForExistence(timeout: 10))
        capture("01-home")
        let openChat = app.buttons["open-chat"]
        openChat.tap()
        let chatField = app.textFields["chat-input"]
        let chatTextView = app.textViews["chat-input"]
        if !(chatField.waitForExistence(timeout: 5) || chatTextView.exists) {
            openChat.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        guard chatField.waitForExistence(timeout: 5) || chatTextView.waitForExistence(timeout: 5) else {
            return XCTFail("点击主按钮后未打开聊天界面")
        }
        capture("02-chat")
        let input = chatField.exists ? chatField : chatTextView
        input.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) {
            input.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        input.typeText("Hello")
        app.buttons["send-chat"].tap()
        XCTAssertTrue(app.staticTexts["assistant-message-label"].waitForExistence(timeout: 8))
        app.buttons["关闭"].firstMatch.tap()
        app.buttons["健康"].firstMatch.tap()
        capture("03-health")
        app.segmentedControls.buttons["趋势"].tap()
        capture("04-trends")
        app.segmentedControls.buttons["报告"].tap()
        capture("05-reports")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "9月5日体检报告")).firstMatch.tap()
        capture("05b-report-detail")
        app.buttons["服务"].firstMatch.tap()
        capture("06-services")
        app.buttons["我的"].firstMatch.tap()
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
        app.buttons["健康"].firstMatch.tap()
        app.buttons["metric-血压"].tap()
        app.buttons["添加血压记录"].tap()
        let primary = app.textFields["reading-primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 5))
        primary.tap(); primary.typeText("123")
        app.textFields["reading-secondary"].tap(); app.textFields["reading-secondary"].typeText("77")
        app.buttons["save-reading"].tap()
        XCTAssertTrue(app.staticTexts["123/77"].waitForExistence(timeout: 5))
        capture("10-record-saved")
        app.buttons["服务"].firstMatch.tap()
        app.buttons["service-帮预约"].tap()
        app.buttons["保存预约意向"].tap()
        XCTAssertTrue(app.staticTexts["尚未提交至医疗机构"].exists)
        capture("11-booking-saved")
        app.buttons["查看服务记录"].tap()
        app.buttons["取消意向"].firstMatch.tap()
        XCTAssertTrue(app.buttons["确认取消"].waitForExistence(timeout: 5))
        app.buttons["确认取消"].tap()
        XCTAssertTrue(app.staticTexts["已取消本地意向"].waitForExistence(timeout: 5))
    }
    func testLargeTextAndLandscape() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--large-text"]
        app.launch()
        XCTAssertTrue(app.buttons["首页"].firstMatch.waitForExistence(timeout: 10))
        capture("12-large-text-home")
        app.buttons["健康"].firstMatch.tap()
        capture("13-large-text-health")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["健康"].firstMatch.exists)
        capture("14-landscape")
        XCUIDevice.shared.orientation = .portrait
    }

    func testDoctorReplyAndContextualFill() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let doctorPool = app.buttons["doctor-reply-pool"]
        XCTAssertTrue(doctorPool.waitForExistence(timeout: 10))
        doctorPool.tap()
        XCTAssertTrue(app.navigationBars["医生回复"].waitForExistence(timeout: 5))

        app.buttons["首页"].firstMatch.tap()
        app.buttons["健康"].firstMatch.tap()
        app.buttons["metric-血压"].tap()
        app.buttons["添加血压记录"].tap()

        let summon = app.buttons["global-assistant"]
        XCTAssertTrue(summon.waitForExistence(timeout: 5))
        summon.tap()
        let input = app.textFields["chat-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("晨起血压 123/77 mmHg")
        app.buttons["send-chat"].tap()
        let fill = app.buttons["fill-back"]
        XCTAssertTrue(fill.waitForExistence(timeout: 5))
        fill.tap()

        XCTAssertEqual(app.textFields["reading-primary"].value as? String, "123")
        XCTAssertEqual(app.textFields["reading-secondary"].value as? String, "77")
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
