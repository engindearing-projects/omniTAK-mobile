import XCTest

/// App Preview (video) recording automation
/// These tests are designed to be recorded with simctl recordVideo
/// Run: ./record_with_test.sh testCorePreview
class AppPreviewRecordingTests: ScreenshotTestCase {

    /// Preview 1: Core functionality (~20 seconds)
    /// Shows: Map → Drop marker → Radial menu → Send to team
    func testCorePreview() {
        // Scene 1: Map loads (3s)
        Thread.sleep(forTimeInterval: 3.0)

        // Scene 2: Pan around map (4s)
        let window = app.windows.firstMatch
        let center = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let offset = window.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3))
        center.press(forDuration: 0.1, thenDragTo: offset)
        Thread.sleep(forTimeInterval: 2.0)

        // Scene 3: Long press for radial menu (5s)
        longPressCenter(duration: 0.8)
        Thread.sleep(forTimeInterval: 2.0)

        // Scene 4: Select "Drop Point" from radial menu (3s)
        let dropButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'point' OR label CONTAINS[c] 'marker'")).firstMatch
        if dropButton.exists {
            dropButton.tap()
            Thread.sleep(forTimeInterval: 2.0)
        } else {
            app.tap() // Dismiss
            Thread.sleep(forTimeInterval: 1.0)
        }

        // Scene 5: Show marker info (3s)
        Thread.sleep(forTimeInterval: 3.0)

        // Total: ~20s
    }

    /// Preview 2: Team coordination (~20 seconds)
    /// Shows: Connect → See team → Open chat → Send message
    func testTeamPreview() {
        // Scene 1: Open menu (2s)
        openMenu()
        Thread.sleep(forTimeInterval: 2.0)

        // Scene 2: Navigate to servers/connect (3s)
        let connectButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'connect' OR label CONTAINS[c] 'server'")).firstMatch
        if connectButton.exists {
            connectButton.tap()
            Thread.sleep(forTimeInterval: 3.0)
        }

        // Scene 3: Go back and show team positions (4s)
        goBack()
        Thread.sleep(forTimeInterval: 4.0)

        // Scene 4: Open team/contacts (3s)
        openMenu()
        let teamButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'team' OR label CONTAINS[c] 'contact'")).firstMatch
        if teamButton.exists {
            teamButton.tap()
            Thread.sleep(forTimeInterval: 3.0)
        }

        // Scene 5: Open chat (3s)
        goBack()
        openMenu()
        let chatButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'chat'")).firstMatch
        if chatButton.exists {
            chatButton.tap()
            Thread.sleep(forTimeInterval: 3.0)
        }

        // Scene 6: Type and show (3s)
        Thread.sleep(forTimeInterval: 3.0)

        // Total: ~21s
    }

    /// Preview 3: Tactical features (~20 seconds)
    /// Shows: 3D map → Measurement → Route planning → Offline maps
    func testTacticalPreview() {
        // Scene 1: Map overview (3s)
        Thread.sleep(forTimeInterval: 3.0)

        // Scene 2: Switch to 3D view (4s)
        openMenu()
        let threeDButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '3D'")).firstMatch
        if threeDButton.exists {
            threeDButton.tap()
            Thread.sleep(forTimeInterval: 4.0)
        }

        // Scene 3: Use measurement tool (4s)
        goBack()
        openMenu()
        let measureButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'measure'")).firstMatch
        if measureButton.exists {
            measureButton.tap()
            Thread.sleep(forTimeInterval: 4.0)
        }

        // Scene 4: Route planning (4s)
        goBack()
        openMenu()
        let routeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'route'")).firstMatch
        if routeButton.exists {
            routeButton.tap()
            Thread.sleep(forTimeInterval: 4.0)
        }

        // Scene 5: Offline maps (4s)
        goBack()
        openMenu()
        let offlineButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'offline'")).firstMatch
        if offlineButton.exists {
            offlineButton.tap()
            Thread.sleep(forTimeInterval: 4.0)
        }

        // Total: ~23s
    }
}
