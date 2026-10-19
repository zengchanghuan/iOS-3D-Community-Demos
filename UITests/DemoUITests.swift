import XCTest

final class DemoUITests: XCTestCase {
    func testThreeDemos() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["01 · 模型浏览与骨骼动画"].waitForExistence(timeout: 10))
        app.buttons["01 · 模型浏览与骨骼动画"].tap()
        login(app)
        app.buttons["library.featured"].tap()
        XCTAssertTrue(app.buttons["暂停动画"].waitForExistence(timeout: 15))
        screenshot("SceneKit-Fox", app)
        app.buttons["暂停动画"].tap()
        XCTAssertTrue(app.buttons["继续动画"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["02 · PBR 与纹理内存实验"].tap()
        let ready = NSPredicate(format: "label CONTAINS %@", "Metal device allocated")
        XCTAssertTrue(app.staticTexts.matching(ready).firstMatch.waitForExistence(timeout: 30))
        screenshot("Filament-PNG", app)
        setOn(app.switches["ASTC 4×4 对照模型"])
        let astc = NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "ASTC 4×4 sRGB", "此设备不支持 ASTC")
        XCTAssertTrue(app.staticTexts.matching(astc).firstMatch.waitForExistence(timeout: 30))
        screenshot("Filament-ASTC", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["03 · 泄漏与帧率实验"].tap()
        app.buttons["打开 3D 详情页"].tap()
        app.buttons["关闭"].tap()
        XCTAssertTrue(app.staticTexts["关闭详情页后仍存活：0"].waitForExistence(timeout: 5))
        setOn(app.switches["注入闭包强引用环"])
        app.buttons["打开 3D 详情页"].tap()
        app.buttons["关闭"].tap()
        XCTAssertTrue(app.staticTexts["关闭详情页后仍存活：1"].waitForExistence(timeout: 5))
        app.buttons["解除所有实验引用环"].tap()
        XCTAssertTrue(app.staticTexts["关闭详情页后仍存活：0"].exists)
        screenshot("Performance", app)
    }
    func testLoginGalleryAndScroll() {
        let app = XCUIApplication()
        app.launchArguments = ["--capture-fps"]
        app.launch()
        app.buttons["01 · 模型浏览与骨骼动画"].tap()
        screenshot("Login", app)
        XCTAssertEqual(app.textFields["login.email"].value as? String, "demo@3dlab.local")
        app.buttons["login.submit"].tap()
        XCTAssertTrue(app.buttons["library.featured"].waitForExistence(timeout: 5))
        screenshot("Gallery", app)
        let scroll = app.scrollViews["library.scroll"]
        for _ in 0..<5 { scroll.swipeUp(velocity: .slow); scroll.swipeDown(velocity: .slow) }
        screenshot("Gallery-Scroll", app)
        app.buttons["library.featured"].tap()
        XCTAssertTrue(app.buttons["暂停动画"].waitForExistence(timeout: 15))
        let canvas = app.otherElements["model.canvas"]
        for _ in 0..<6 {
            let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0)
        }
        screenshot("SceneKit-Interaction", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["community.tab.1"].tap()
        screenshot("Account", app)
        app.buttons["account.signout"].tap()
        XCTAssertTrue(app.buttons["login.submit"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.buttons["01 · 模型浏览与骨骼动画"].tap()
        XCTAssertTrue(app.buttons["login.submit"].exists)
    }
    private func login(_ app: XCUIApplication) {
        app.buttons["填入演示账号"].tap()
        app.buttons["login.submit"].tap()
        XCTAssertTrue(app.buttons["library.featured"].waitForExistence(timeout: 5))
    }
    private func setOn(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(element.value as? String, "1")
    }
    private func screenshot(_ name: String, _ app: XCUIApplication) {
        Thread.sleep(forTimeInterval: 0.8) // Let navigation transitions finish before the evidence capture.
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
