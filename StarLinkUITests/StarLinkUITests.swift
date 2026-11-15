import XCTest

/// 模拟器功能验收（对应第一期 E1–E5 的模拟器版）：
/// 登录成功 / 失败提示 / 杀进程保活 / 四 Tab 切换 / 退出不可返回 / 聊天 Demo 可见
final class StarLinkUITests: XCTestCase {

    private func launch(fresh: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        if fresh { app.launchArguments.append("UITEST_FRESH") }
        app.launch()
        return app
    }

    private func login(_ app: XCUIApplication, account: String, password: String) {
        let acctField = app.textFields["账号"]
        XCTAssertTrue(acctField.waitForExistence(timeout: 8), "登录页账号框未出现")
        acctField.tap()
        acctField.typeText(account)

        let pwdField = app.secureTextFields["密码"]
        XCTAssertTrue(pwdField.waitForExistence(timeout: 3), "密码框未出现")
        pwdField.tap()
        pwdField.typeText(password)

        let loginButton = app.buttons["登录"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 3))
        loginButton.tap()
    }

    private func assertLoggedIn(_ app: XCUIApplication) {
        let myTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(myTab.waitForExistence(timeout: 10), "登录后四 Tab 未出现")
    }

    // MARK: - E2 登录失败提示

    func test01LoginFailureShowsInlineError() {
        let app = launch()
        login(app, account: "TEST_1001", password: "wrong-password")
        let error = app.staticTexts["账号或密码错误"]
        XCTAssertTrue(error.waitForExistence(timeout: 8), "失败提示未出现")
    }

    // MARK: - E1 登录成功 + E4 四 Tab 切换 + 聊天 Demo 可见

    func test02LoginSuccessAndTabsAndChatDemo() {
        let app = launch()
        login(app, account: "TEST_1001", password: "123456")
        assertLoggedIn(app)

        // 四 Tab 依次切换
        for tab in ["消息", "客户", "工作台", "我的"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.exists, "Tab 缺失: \(tab)")
            button.tap()
        }

        // Debug 构建的聊天 Demo：种子会话可见
        app.tabBars.buttons["消息"].tap()
        let seed = app.staticTexts["TEST_张三"]
        XCTAssertTrue(seed.waitForExistence(timeout: 5), "聊天 Demo 种子会话未显示")
    }

    // MARK: - E3 杀进程重开保持登录

    func test03RelaunchKeepsLogin() {
        let app = launch()
        login(app, account: "TEST_1001", password: "123456")
        assertLoggedIn(app)

        app.terminate()
        let relaunched = launch(fresh: false)
        assertLoggedIn(relaunched)
        XCTAssertFalse(relaunched.buttons["登录"].exists, "重启后不应回到登录页")
    }

    // MARK: - E5 退出后无法返回内页

    func test04LogoutCannotReturn() {
        let app = launch()
        login(app, account: "TEST_1001", password: "123456")
        assertLoggedIn(app)

        app.tabBars.buttons["我的"].tap()
        let logoutRow = app.buttons["退出登录"]
        XCTAssertTrue(logoutRow.waitForExistence(timeout: 5), "退出登录入口未出现")
        logoutRow.tap()

        let confirm = app.sheets.buttons["退出登录"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "退出确认弹窗未出现")
        confirm.tap()

        let loginButton = app.buttons["登录"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 8), "退出后未回到登录页")
        XCTAssertFalse(app.tabBars.buttons["我的"].exists, "退出后不应还能看到内页 Tab")
    }
}
