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
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
