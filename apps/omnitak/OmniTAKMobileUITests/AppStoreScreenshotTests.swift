import XCTest

/// Automated App Store screenshot capture
/// Run with: xcodebuild test -project OmniTAKMobile.xcodeproj -scheme OmniTAKMobileUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max'
class AppStoreScreenshotTests: ScreenshotTestCase {

    /// Main test that captures all App Store screenshots in sequence
    func testCaptureAllScreenshots() {
        // Screenshot 1: Map Overview with units
        captureMapOverview()

        // Screenshot 2: Radial Menu
        captureRadialMenu()

        // Screenshot 3: Team/Contact List
        captureTeamTracking()

        // Screenshot 4: Chat View
        captureChatView()

        // Screenshot 5: Quick Connect
        captureQuickConnect()

        // Screenshot 6: Settings
        captureSettings()

        // Screenshot 7: Offline Maps
        captureOfflineMaps()

        // Screenshot 8: 3D Map View
        capture3DMap()

        // Screenshot 9: Route Planning
        captureRoutePlanning()

        // Screenshot 10: Measurement Tools
        captureMeasurement()
    }

    // MARK: - Individual Screenshot Captures

    func captureMapOverview() {
        // Wait for map to load
        Thread.sleep(forTimeInterval: 2.0)
        takeScreenshot(named: "map_overview")
    }

    func captureRadialMenu() {
        // Long press to show radial menu
        longPressCenter(duration: 0.8)
        Thread.sleep(forTimeInterval: 0.5)
        takeScreenshot(named: "radial_menu")

        // Dismiss
        app.tap()
        Thread.sleep(forTimeInterval: 0.3)
    }

    func captureTeamTracking() {
        openMenu()

        // Look for team/contacts option
        let teamButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'team' OR label CONTAINS[c] 'contact'")).firstMatch
        if teamButton.waitForExistence(timeout: 3) {
            teamButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            takeScreenshot(named: "team_tracking")
            goBack()
        } else {
            // Take menu screenshot instead
            takeScreenshot(named: "navigation_menu")
            dismissModal()
        }
    }

    func captureChatView() {
        openMenu()

        let chatButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'chat' OR label CONTAINS[c] 'message'")).firstMatch
        if chatButton.waitForExistence(timeout: 3) {
            chatButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            takeScreenshot(named: "chat")
            goBack()
        }
    }

    func captureQuickConnect() {
        openMenu()

        let connectButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'connect' OR label CONTAINS[c] 'server'")).firstMatch
        if connectButton.waitForExistence(timeout: 3) {
            connectButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            takeScreenshot(named: "quick_connect")
            goBack()
        }
    }

    func captureSettings() {
        openMenu()

        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'setting'")).firstMatch
        if settingsButton.waitForExistence(timeout: 3) {
            settingsButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            takeScreenshot(named: "settings")
            goBack()
        }
    }

    func captureOfflineMaps() {
        openMenu()

        let offlineButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'offline' OR label CONTAINS[c] 'download'")).firstMatch
        if offlineButton.waitForExistence(timeout: 3) {
            offlineButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            takeScreenshot(named: "offline_maps")
            goBack()
        }
    }

    func capture3DMap() {
        openMenu()

        let mapButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '3D' OR label CONTAINS[c] 'terrain'")).firstMatch
        if mapButton.waitForExistence(timeout: 3) {
            mapButton.tap()
            Thread.sleep(forTimeInterval: 1.0)
            takeScreenshot(named: "3d_map")
            goBack()
        }
    }

    func captureRoutePlanning() {
        openMenu()

        let routeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'route' OR label CONTAINS[c] 'navigation'")).firstMatch
        if routeButton.waitForExistence(timeout: 3) {
            routeButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            takeScreenshot(named: "route_planning")
            goBack()
        }
    }

    func captureMeasurement() {
        openMenu()

        let measureButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'measure' OR label CONTAINS[c] 'distance'")).firstMatch
        if measureButton.waitForExistence(timeout: 3) {
            measureButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            takeScreenshot(named: "measurement")
            goBack()
        }
    }
}

// MARK: - Individual Feature Tests (for targeted captures)

extension AppStoreScreenshotTests {

    /// Capture just the map view
    func testMapOnly() {
        Thread.sleep(forTimeInterval: 2.0)
        takeScreenshot(named: "map_main")
    }

    /// Capture military features
    func testMilitaryFeatures() {
        openMenu()

        // SALUTE Report
        let saluteButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'salute'")).firstMatch
        if saluteButton.waitForExistence(timeout: 3) {
            saluteButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            takeScreenshot(named: "salute_report")
            goBack()
        }

        // MEDEVAC
        openMenu()
        let medevacButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'medevac' OR label CONTAINS[c] '9-line'")).firstMatch
        if medevacButton.waitForExistence(timeout: 3) {
            medevacButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            takeScreenshot(named: "medevac")
            goBack()
        }
    }

    /// Capture Meshtastic features
    func testMeshtasticFeatures() {
        openMenu()

        let meshButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'mesh'")).firstMatch
        if meshButton.waitForExistence(timeout: 3) {
            meshButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            takeScreenshot(named: "meshtastic")
            goBack()
        }
    }
}
