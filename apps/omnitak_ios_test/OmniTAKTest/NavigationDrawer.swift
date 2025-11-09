import SwiftUI

// MARK: - Navigation Drawer for iOS (ATAK Style)

struct NavigationDrawer: View {
    @Binding var isOpen: Bool
    @Binding var currentScreen: String
    let userName: String
    let userCallsign: String
    let connectionStatus: String
    let onNavigate: (String) -> Void

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
                HStack(spacing: 0) {
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
                    .frame(width: 280)
                    .background(Color(hex: "#1E1E1E"))
                    .overlay(
                        Rectangle()
                            .frame(width: 2)
                            .foregroundColor(Color(hex: "#FFFC00"))
                            .shadow(color: Color(hex: "#FFFC00").opacity(0.5), radius: 4),
                        alignment: .trailing
                    )
                    .transition(.move(edge: .leading))

                    Spacer()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isOpen)
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
            // iTAK Logo with underline
            VStack(alignment: .leading, spacing: 4) {
                Text("iTAK")
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

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
