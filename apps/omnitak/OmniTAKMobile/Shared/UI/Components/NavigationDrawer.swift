import SwiftUI

// MARK: - Navigation Drawer for iOS (ATAK Style)

struct NavigationDrawer: View {
    @Binding var isOpen: Bool
    @Binding var currentScreen: String
    let userName: String
    let userCallsign: String
    let connectionStatus: String
    let onNavigate: (String) -> Void

    // Detect orientation
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var isLandscape: Bool {
        // Landscape when height is compact (iPhone landscape)
        // or both are regular (iPad in any orientation - treat as landscape for ATAK-style menu)
        verticalSizeClass == .compact || (horizontalSizeClass == .regular && verticalSizeClass == .regular)
    }

    var body: some View {
        ZStack {
            // Overlay background
            if isOpen {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isOpen = false
                        }
                    }
                    .transition(.opacity)

                // Drawer panel with slide-in animation
                // In landscape (ATAK style), drawer slides from right
                // In portrait, drawer slides from left
                HStack(spacing: 0) {
                    // In landscape, add spacer first to push drawer to right side
                    if isLandscape {
                        Spacer(minLength: 0)
                    }

                    VStack(spacing: 0) {
                        // Header with user info - ATAK Style
                        DrawerHeader(
                            userName: userName,
                            userCallsign: userCallsign,
                            connectionStatus: connectionStatus
                        )

                        // Menu items
                        ScrollView {
                            VStack(spacing: 0) {
                                DrawerMenuItem(
                                    icon: "map.fill",
                                    title: "Map",
                                    isActive: currentScreen == "map"
                                ) {
                                    handleNavigation("map")
                                }

                                DrawerMenuItem(
                                    icon: "person.3.fill",
                                    title: "Contacts",
                                    isActive: currentScreen == "contacts"
                                ) {
                                    handleNavigation("contacts")
                                }

                                DrawerMenuItem(
                                    icon: "message.fill",
                                    title: "Team Chat",
                                    isActive: currentScreen == "chat"
                                ) {
                                    handleNavigation("chat")
                                }

                                DrawerMenuItem(
                                    icon: "person.3.sequence.fill",
                                    title: "Team Management",
                                    isActive: currentScreen == "teams"
                                ) {
                                    handleNavigation("teams")
                                }

                                DrawerMenuItem(
                                    icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                                    title: "Route Planning",
                                    isActive: currentScreen == "routes"
                                ) {
                                    handleNavigation("routes")
                                }

                                DrawerMenuItem(
                                    icon: "square.dashed",
                                    title: "Geofences",
                                    isActive: currentScreen == "geofences"
                                ) {
                                    handleNavigation("geofences")
                                }

                                DrawerMenuItem(
                                    icon: "record.circle",
                                    title: "Track Recording",
                                    isActive: currentScreen == "tracks"
                                ) {
                                    handleNavigation("tracks")
                                }

                                DrawerMenuItem(
                                    icon: "antenna.radiowaves.left.and.right",
                                    title: "Position Broadcasting",
                                    isActive: currentScreen == "selfsa"
                                ) {
                                    handleNavigation("selfsa")
                                }

                                DrawerMenuItem(
                                    icon: "dot.radiowaves.left.and.right",
                                    title: "Meshtastic Mesh",
                                    isActive: currentScreen == "meshtastic"
                                ) {
                                    handleNavigation("meshtastic")
                                }

                                // Emergency Beacon - highlighted with red icon
                                EmergencyDrawerMenuItem(
                                    isActive: currentScreen == "emergency"
                                ) {
                                    handleNavigation("emergency")
                                }

                                Divider()
                                    .background(Color(hex: "#3A3A3A"))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)

                                // Analysis Tools Section
                                Text("ANALYSIS TOOLS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "#888888"))
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 4)

                                DrawerMenuItem(
                                    icon: "chart.line.uptrend.xyaxis",
                                    title: "Elevation Profile",
                                    isActive: currentScreen == "elevation"
                                ) {
                                    handleNavigation("elevation")
                                }

                                DrawerMenuItem(
                                    icon: "eye.fill",
                                    title: "Line of Sight",
                                    isActive: currentScreen == "los"
                                ) {
                                    handleNavigation("los")
                                }

                                DrawerMenuItem(
                                    icon: "rectangle.3.group.fill",
                                    title: "Unit Hierarchy",
                                    isActive: currentScreen == "echelon"
                                ) {
                                    handleNavigation("echelon")
                                }

                                DrawerMenuItem(
                                    icon: "arrow.triangle.2.circlepath",
                                    title: "Mission Package Sync",
                                    isActive: currentScreen == "missionsync"
                                ) {
                                    handleNavigation("missionsync")
                                }

                                Divider()
                                    .background(Color(hex: "#3A3A3A"))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)

                                DrawerMenuItem(
                                    icon: "gearshape.fill",
                                    title: "Settings",
                                    isActive: currentScreen == "settings"
                                ) {
                                    handleNavigation("settings")
                                }

                                DrawerMenuItem(
                                    icon: "network",
                                    title: "Network Connections",
                                    isActive: currentScreen == "servers"
                                ) {
                                    handleNavigation("servers")
                                }

                                DrawerMenuItem(
                                    icon: "puzzlepiece.fill",
                                    title: "Plugins",
                                    isActive: currentScreen == "plugins"
                                ) {
                                    handleNavigation("plugins")
                                }

                                DrawerMenuItem(
                                    icon: "wrench.and.screwdriver.fill",
                                    title: "Tools",
                                    isActive: currentScreen == "tools"
                                ) {
                                    handleNavigation("tools")
                                }

                                Divider()
                                    .background(Color(hex: "#3A3A3A"))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)

                                DrawerMenuItem(
                                    icon: "info.circle.fill",
                                    title: "About",
                                    isActive: currentScreen == "about"
                                ) {
                                    handleNavigation("about")
                                }
                            }
                            .padding(.top, 8)
                        }

                        // Footer
                        DrawerFooter()
                    }
                    .frame(width: 280)  // Slightly wider for landscape ATAK style
                    .background(Color(hex: "#1E1E1E"))
                    .overlay(
                        // Yellow accent border
                        Rectangle()
                            .frame(width: 2)
                            .foregroundColor(Color(hex: "#FFFC00"))
                            .shadow(color: Color(hex: "#FFFC00").opacity(0.5), radius: 4),
                        // Border on left side of drawer in landscape (leading), right side in portrait (trailing)
                        alignment: isLandscape ? .leading : .trailing
                    )
                    // Critical: slide from RIGHT in landscape (.trailing edge), LEFT in portrait (.leading edge)
                    .transition(.move(edge: isLandscape ? .trailing : .leading))

                    // In portrait, add spacer after to push drawer to left side
                    if !isLandscape {
                        Spacer(minLength: 0)
                    }
                }
                .ignoresSafeArea(.all, edges: .vertical)  // Full height drawer
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isOpen)  // Smoother ATAK-style animation
    }

    private func handleNavigation(_ screen: String) {
        onNavigate(screen)
        withAnimation(.easeInOut(duration: 0.3)) {
            isOpen = false
        }
    }
}

// MARK: - Drawer Header

struct DrawerHeader: View {
    let userName: String
    let userCallsign: String
    let connectionStatus: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // OmniTAK Mobile Logo with underline
            VStack(alignment: .leading, spacing: 4) {
                Text("OmniTAK Mobile")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "#FFFC00"))

                Rectangle()
                    .fill(Color(hex: "#FFFC00"))
                    .frame(width: 60, height: 3)
                    .cornerRadius(2)
            }

            // User Info
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(userCallsign)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    Text(userName)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                }
            }
            .padding(12)
            .background(Color(hex: "#FFFC00").opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#FFFC00").opacity(0.3), lineWidth: 1)
            )

            // Connection status with LED indicator
            HStack(spacing: 12) {
                // LED indicator
                Circle()
                    .fill(connectionStatusColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: connectionStatusColor, radius: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text("STATUS")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(hex: "#999999"))

                    Text(connectionStatusText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(connectionStatusColor)
                }

                Spacer()
            }
            .padding(12)
            .background(Color(hex: "#1E1E1E"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#3A3A3A"), lineWidth: 1)
            )
        }
        .padding(20)
        .padding(.top, 40) // Account for status bar
        .background(Color(hex: "#2A2A2A"))
        .overlay(
            Rectangle()
                .frame(height: 2)
                .foregroundColor(Color(hex: "#FFFC00")),
            alignment: .bottom
        )
    }

    private var connectionStatusColor: Color {
        switch connectionStatus {
        case "CONNECTED":
            return Color(hex: "#4CAF50")
        case "CONNECTING":
            return Color(hex: "#FFA500")
        case "ERROR":
            return Color(hex: "#FF5252")
        default:
            return Color(hex: "#666666")
        }
    }

    private var connectionStatusText: String {
        switch connectionStatus {
        case "CONNECTED":
            return "Connected to TAK Server"
        case "CONNECTING":
            return "Connecting..."
        case "ERROR":
            return "Connection Error"
        default:
            return "Not Connected"
        }
    }
}

// MARK: - Drawer Menu Item

struct DrawerMenuItem: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 14, weight: isActive ? .bold : .regular))
                    .foregroundColor(isActive ? Color(hex: "#FFFC00") : .white)

                Spacer()
            }
            .padding(16)
            .padding(.leading, 20)
            .background(isActive ? Color(hex: "#333333") : Color.clear)
            .overlay(
                Rectangle()
                    .fill(Color(hex: "#FFFC00"))
                    .frame(width: 4),
                alignment: .leading
            )
            .opacity(isActive ? 1 : 1)
        }
    }
}

// MARK: - Drawer Footer

struct DrawerFooter: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("Powered by omni-TAK")
                .font(.system(size: 9))
                .foregroundColor(Color(hex: "#666666"))

            Text("v1.0.0")
                .font(.system(size: 9))
                .foregroundColor(Color(hex: "#666666"))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#1E1E1E"))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#3A3A3A")),
            alignment: .top
        )
    }
}

// MARK: - Emergency Drawer Menu Item (with special styling)

struct EmergencyDrawerMenuItem: View {
    let isActive: Bool
    let action: () -> Void

    @ObservedObject var emergencyService = EmergencyBeaconService.shared
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    if emergencyService.emergencyState.isActive {
                        Circle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .scaleEffect(pulse ? 1.2 : 1.0)
                    }

                    Image(systemName: emergencyService.emergencyState.isActive ? "exclamationmark.triangle.fill" : "sos")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                        .frame(width: 24)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Emergency SOS")
                        .font(.system(size: 14, weight: isActive ? .bold : .semibold))
                        .foregroundColor(isActive ? Color.red : .white)

                    if emergencyService.emergencyState.isActive {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(3)
                    }
                }

                Spacer()
            }
            .padding(16)
            .padding(.leading, 20)
            .background(isActive ? Color(hex: "#333333") : Color.clear)
            .overlay(
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 4),
                alignment: .leading
            )
        }
        .onAppear {
            if emergencyService.emergencyState.isActive {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
}

