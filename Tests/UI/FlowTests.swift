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
        let chatField = app.textFields["chat-input"]
        let chatTextView = app.textViews["chat-input"]
        XCTAssertTrue(chatField.waitForExistence(timeout: 5) || chatTextView.waitForExistence(timeout: 5))
        let input = chatField.exists ? chatField : chatTextView
        input.tap()
        input.typeText("晨起血压 123/77 mmHg")
        app.buttons["send-chat"].tap()
        let fill = app.buttons["fill-back"]
        XCTAssertTrue(fill.waitForExistence(timeout: 5))
        fill.tap()

        XCTAssertEqual(app.textFields["reading-primary"].value as? String, "123")
        XCTAssertEqual(app.textFields["reading-secondary"].value as? String, "77")
    }

    func testShiyangPantryToCookingJourney() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let entry = app.buttons["open-shiyang"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()

        let start = app.buttons["start-shiyang"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let consent = app.buttons["continue-shiyang-consent"]
        XCTAssertTrue(consent.waitForExistence(timeout: 5))
        capture("15-shiyang-consent")
        consent.tap()

        let nextQuestion = app.buttons["next-shiyang-question"]
        XCTAssertTrue(nextQuestion.waitForExistence(timeout: 5))
        capture("16-shiyang-profile")
        for _ in 0..<7 {
            nextQuestion.tap()
        }

        let confirm = app.buttons["confirm-shiyang-profile"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        capture("17-shiyang-summary")
        confirm.tap()
        XCTAssertTrue(app.otherElements["shiyang-recommendation"].waitForExistence(timeout: 5))
        capture("18-shiyang-home")

        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "看看家里有什么")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["家里现在有什么？"].waitForExistence(timeout: 5))
        capture("19-shiyang-pantry")
        app.buttons["generate-shiyang-recipe"].tap()

        XCTAssertTrue(app.otherElements["shiyang-recommendation"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "为什么这样推荐")).firstMatch.tap()
        XCTAssertTrue(app.buttons["start-cooking"].waitForExistence(timeout: 5))
        capture("20-shiyang-recipe")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "开始做饭")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["先把食材请上桌"].waitForExistence(timeout: 5))
        capture("21-shiyang-ingredients")
        app.buttons["食材备好了"].tap()
        XCTAssertTrue(app.buttons["next-cooking-step"].waitForExistence(timeout: 5))
        capture("22-shiyang-cooking")
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
