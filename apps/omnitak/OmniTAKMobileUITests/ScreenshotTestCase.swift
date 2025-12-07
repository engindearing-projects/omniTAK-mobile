import XCTest

/// Base class for App Store screenshot automation
class ScreenshotTestCase: XCTestCase {

    var app: XCUIApplication!
    var screenshotCounter = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo-mode"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Screenshot Helpers

    /// Take a screenshot and save as XCTest attachment
    /// Screenshots are saved in the .xcresult bundle and can be exported with:
    /// xcrun xcresulttool export --path TestResults.xcresult --output-path ./Screenshots
    func takeScreenshot(named name: String, delay: TimeInterval = 0.5) {
        // Wait for animations to settle
        Thread.sleep(forTimeInterval: delay)

        screenshotCounter += 1
        let paddedNumber = String(format: "%02d", screenshotCounter)
        let filename = "\(paddedNumber)_\(name)"

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = filename
        attachment.lifetime = .keepAlways
        add(attachment)

        print("📸 Screenshot: \(filename)")
    }

    // MARK: - Navigation Helpers

    /// Wait for an element to appear
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }

    /// Tap a button by its accessibility identifier or label
    func tapButton(_ identifier: String) {
        let button = app.buttons[identifier]
        if button.waitForExistence(timeout: 3) {
            button.tap()
        } else {
            // Try by label
            let buttonByLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", identifier)).firstMatch
            if buttonByLabel.exists {
                buttonByLabel.tap()
            }
        }
    }

    /// Tap a tab bar item
    func tapTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.waitForExistence(timeout: 3) {
            tab.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    /// Tap navigation back button
    func goBack() {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    /// Dismiss any presented sheet or modal
    func dismissModal() {
        // Try pull-down gesture
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.1, thenDragTo: end)
        Thread.sleep(forTimeInterval: 0.3)
    }

    /// Long press at center of screen (for radial menu)
    func longPressCenter(duration: TimeInterval = 0.5) {
        let window = app.windows.firstMatch
        let center = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: duration)
        Thread.sleep(forTimeInterval: 0.3)
    }

    /// Scroll down in the current view
    func scrollDown() {
        let window = app.windows.firstMatch
        window.swipeUp()
        Thread.sleep(forTimeInterval: 0.3)
    }

    /// Open the navigation drawer / menu
    func openMenu() {
        // Try hamburger menu button
        let menuButton = app.buttons["menu"]
        if menuButton.waitForExistence(timeout: 2) {
            menuButton.tap()
        } else {
            // Try swipe from left edge
            let window = app.windows.firstMatch
            let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5))
            let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        Thread.sleep(forTimeInterval: 0.3)
    }
}
