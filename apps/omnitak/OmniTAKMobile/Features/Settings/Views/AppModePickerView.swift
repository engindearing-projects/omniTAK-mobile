//
//  AppModePickerView.swift
//  OmniTAKMobile
//
//  Mode selection sheet for switching between app personas:
//  Tactical, Fire/Rescue, SAR, Civilian
//

import SwiftUI

struct AppModePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var modeManager = AppModeManager.shared
    @State private var selectedMode: AppMode

    init() {
        _selectedMode = State(initialValue: AppModeManager.shared.currentMode)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1A1A1A")
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    // Header
                    Text("Select App Mode")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.top, 8)

                    // Mode options
                    VStack(spacing: 12) {
                        ForEach(AppMode.allCases) { mode in
                            ModeOptionCard(
                                mode: mode,
                                isSelected: selectedMode == mode,
                                onSelect: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedMode = mode
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer()

                    // Apply button
                    Button(action: {
                        modeManager.setMode(selectedMode)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: selectedMode.icon)
                            Text("Apply \(selectedMode.displayName) Mode")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedMode.accentColor)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("App Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Mode Option Card

struct ModeOptionCard: View {
    let mode: AppMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? mode.accentColor : Color(hex: "#2A2A2A"))
                        .frame(width: 50, height: 50)

                    Image(systemName: mode.icon)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .black : mode.accentColor)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text(mode.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(mode.accentColor)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#2A2A2A"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? mode.accentColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

struct AppModePickerView_Previews: PreviewProvider {
    static var previews: some View {
        AppModePickerView()
    }
}
