//
//  ATAKBottomToolbar_Modified.swift
//  OmniTAKTest
//
//  Modified Bottom Toolbar with Chat button
//  INSTRUCTIONS: Replace the ATAKBottomToolbar struct in MapViewController.swift with this version
//

import SwiftUI
import MapKit

// MARK: - ATAK Bottom Toolbar (MODIFIED with Chat)

struct ATAKBottomToolbar: View {
    @Binding var mapType: MKMapType
    @Binding var showLayersPanel: Bool
    @Binding var showDrawingPanel: Bool
    @Binding var showDrawingList: Bool
    @Binding var showChat: Bool  // ADDED
    @Binding var showEmergency: Bool  // ADDED: Emergency beacon
    let onCenterUser: () -> Void
    let onSendCoT: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    // ADDED: Calculate total unread message count
    var totalUnreadCount: Int {
        ChatManager.shared.conversations.reduce(0) { $0 + $1.unreadCount }
    }

    // ADDED: Emergency beacon service
    @ObservedObject var emergencyService = EmergencyBeaconService.shared

    var body: some View {
        HStack(spacing: 20) {
            // Layers
            ToolButton(icon: "square.stack.3d.up.fill", label: "Layers") {
                showLayersPanel.toggle()
            }

            Spacer()

            // ADDED: Emergency/SOS Button (prominent placement)
            EmergencyToolbarButton {
                showEmergency.toggle()
            }

            // Center on User
            ToolButton(icon: "location.fill", label: "GPS") {
                onCenterUser()
            }

            // Send Position
            ToolButton(icon: "paperplane.fill", label: "Broadcast") {
                onSendCoT()
            }

            // Zoom Controls
            VStack(spacing: 8) {
                ToolButton(icon: "plus", label: "", compact: true) {
                    onZoomIn()
                }
                ToolButton(icon: "minus", label: "", compact: true) {
                    onZoomOut()
                }
            }

            Spacer()

            // ADDED: Chat button with unread badge
            ZStack(alignment: .topTrailing) {
                ToolButton(icon: "message.fill", label: "Chat") {
                    showChat.toggle()
                }

                if totalUnreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                        Text("\(totalUnreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 8, y: -8)
                }
            }

            // Drawing Tools
            ToolButton(icon: "pencil.tip.crop.circle", label: "Draw") {
                showDrawingPanel.toggle()
            }

            // Drawing List
            ToolButton(icon: "list.bullet", label: "Shapes") {
                showDrawingList.toggle()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
