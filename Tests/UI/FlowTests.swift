import XCTest

final class FlowTests: XCTestCase {
    func testLiveXuantongConversationWhenRequested() throws {
        let baseURL = ProcessInfo.processInfo.environment["XUANTONG_TEST_BASE_URL"]
            ?? "http://127.0.0.1:8000"
        guard let healthURL = URL(string: baseURL + "/api/health") else {
            throw XCTSkip("Invalid Xuantong URL: \(baseURL).")
        }
        let probe = expectation(description: "Probe Xuantong")
        var backendAvailable = false
        URLSession.shared.dataTask(with: healthURL) { data, response, _ in
            backendAvailable = (response as? HTTPURLResponse)?.statusCode == 200
                && !(data?.isEmpty ?? true)
            probe.fulfill()
        }.resume()
        wait(for: [probe], timeout: 5)
        guard backendAvailable else {
            throw XCTSkip("No Xuantong server is running at \(baseURL).")
        }
        let app = XCUIApplication()
        app.launchArguments = ["--integration-testing", "-apiBaseURL", baseURL]
        app.launch()

        let openChat = app.buttons["open-chat"].firstMatch
        XCTAssertTrue(openChat.waitForExistence(timeout: 10))
        openChat.tap()

        let chatField = app.textFields["chat-input"]
        let chatTextView = app.textViews["chat-input"]
        if !(chatField.waitForExistence(timeout: 5) || chatTextView.exists) {
            openChat.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        guard chatField.waitForExistence(timeout: 5) || chatTextView.waitForExistence(timeout: 5) else {
            return XCTFail("点击常曦入口后未打开聊天界面")
        }
        let input = chatField.exists ? chatField : chatTextView
        input.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) {
            input.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        input.typeText("请说明家庭血压记录的正确方法")
        app.buttons["send-chat"].tap()

        let reply = app.descendants(matching: .any)["assistant-response"].firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 45), "常曦未在界面收到玄同回复")
        XCTAssertTrue(app.staticTexts["assistant-message-label"].exists)
        let workOrder = app.descendants(matching: .any)["work-order-summary"].firstMatch
        XCTAssertTrue(workOrder.waitForExistence(timeout: 150), "玄同回复后未生成照护工单")
        if !workOrder.isHittable {
            app.swipeUp()
        }
        capture("15-live-xuantong-reply")
    }

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

    func testPainAnatomyLayers() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let healthTab = app.buttons["root-tab-健康"]
        XCTAssertTrue(healthTab.waitForExistence(timeout: 10))
        healthTab.tap()
        let painEntry = app.buttons["open-pain-location"]
        let head = app.buttons["pain-region-head"]
        openPainLocation(in: app, entry: painEntry, head: head)
        XCTAssertTrue(head.waitForExistence(timeout: 5))
        capture("15-pain-region-grid")
        // The card artwork breathes subtly; its lower label area remains a
        // stable tap target while the decorative image is moving.
        head.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.88)).tap()
        let model = app.otherElements["pain-anatomy-model"]
        XCTAssertTrue(model.waitForExistence(timeout: 12))
        capture("16-pain-head-surface")
        capture("16-pain-head-surface-model", element: model)
        app.segmentedControls.buttons["标记疼处"].tap()
        model.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.32)).tap()
        let markedStatus = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '已标记 '")).firstMatch
        XCTAssertTrue(markedStatus.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["pain-primary-step"].isEnabled)
        capture("16-pain-head-marked")
        app.segmentedControls.buttons["转动查看"].tap()
        app.segmentedControls.buttons["插画标记"].tap()
        capture("16-pain-head-illustration-front")
        app.segmentedControls.buttons["右侧"].tap()
        capture("16-pain-head-illustration-right")
        app.segmentedControls.buttons["局部三维"].tap()
        app.segmentedControls.buttons["肌肉"].tap()
        capture("17-pain-head-muscle")
        capture("17-pain-head-muscle-model", element: model)
        app.segmentedControls.buttons["骨骼"].tap()
        capture("18-pain-head-skeleton")
        capture("18-pain-head-skeleton-model", element: model)

        // A region drill-down must load the actual local body part, not return
        // to a generic full-body mesh. Exercise the arm model in all layers.
        app.buttons["上一步"].tap()
        let arms = app.buttons["pain-region-arms"]
        XCTAssertTrue(arms.waitForExistence(timeout: 5))
        arms.tap()
        XCTAssertTrue(model.waitForExistence(timeout: 12))
        app.segmentedControls.buttons["体表"].tap()
        capture("19-pain-arms-surface-model", element: model)
        app.segmentedControls.buttons["肌肉"].tap()
        capture("20-pain-arms-muscle-model", element: model)
        app.segmentedControls.buttons["骨骼"].tap()
        capture("21-pain-arms-skeleton-model", element: model)
    }

    func testPainNaturalLanguageIntensity() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let healthTab = app.buttons["root-tab-健康"]
        XCTAssertTrue(healthTab.waitForExistence(timeout: 10))
        healthTab.tap()
        let painEntry = app.buttons["open-pain-location"]
        let head = app.buttons["pain-region-head"]
        openPainLocation(in: app, entry: painEntry, head: head)
        XCTAssertTrue(head.waitForExistence(timeout: 5))
        head.tap()
        let model = app.otherElements["pain-anatomy-model"]
        XCTAssertTrue(model.waitForExistence(timeout: 12))
        capture("22-pain-head-refined-eyes")
        model.swipeLeft()
        capture("22-pain-head-profile-eyes-contained")
        app.buttons["回正"].tap()
        app.segmentedControls.buttons["标记疼处"].tap()
        model.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.32)).tap()
        let next = app.buttons["pain-primary-step"]
        XCTAssertTrue(next.isEnabled)
        capture("22-pain-head-selection-confirmed")
        app.segmentedControls.buttons["片状"].tap()
        model.coordinate(withNormalizedOffset: CGVector(dx: 0.43, dy: 0.30))
            .press(
                forDuration: 0.12,
                thenDragTo: model.coordinate(withNormalizedOffset: CGVector(dx: 0.56, dy: 0.39))
            )
        XCTAssertTrue(app.staticTexts["已标记 2 处"].waitForExistence(timeout: 3))
        app.segmentedControls.buttons["放射"].tap()
        model.coordinate(withNormalizedOffset: CGVector(dx: 0.44, dy: 0.36))
            .press(
                forDuration: 0.12,
                thenDragTo: model.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.48))
            )
        XCTAssertTrue(app.staticTexts["已标记 3 处"].waitForExistence(timeout: 3))
        capture("22-pain-area-and-radiating-marks")
        next.tap()
        let naturalChoice = app.buttons["pain-intensity-5"]
        XCTAssertTrue(naturalChoice.waitForExistence(timeout: 5))
        naturalChoice.tap()
        capture("22-pain-natural-language-intensity")
    }

    private func openPainLocation(in app: XCUIApplication, entry: XCUIElement, head: XCUIElement) {
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        for _ in 0..<4 where !entry.isHittable {
            app.swipeUp()
        }
        for _ in 0..<3 where !head.exists {
            if entry.isHittable {
                entry.tap()
            } else {
                // The persistent glass bar can make XCTest report the lower
                // card as occluded although its leading half is visible.
                let frame = entry.frame
                app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: frame.minX + min(100, frame.width * 0.3), dy: frame.midY))
                    .tap()
            }
            _ = head.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(head.waitForExistence(timeout: 5))
    }

    private func capture(_ name: String) {
        // Accessibility updates precede the end of native tab/navigation transitions.
        Thread.sleep(forTimeInterval: 0.8)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func capture(_ name: String, element: XCUIElement) {
        Thread.sleep(forTimeInterval: 0.4)
        let attachment = XCTAttachment(screenshot: element.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
