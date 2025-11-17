//
//  DataPackageButton.swift
//  OmniTAKMobile
//
//  Compact button for main map UI to access data packages
//

import SwiftUI

struct DataPackageButton: View {
    @ObservedObject var packageManager: DataPackageManager
    @Binding var showDataPackages: Bool

    var body: some View {
        Button(action: {
            showDataPackages = true
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#FFFC00"))

                    // Badge showing number of packages
                    if !packageManager.packages.isEmpty {
                        Text("\(packageManager.packages.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Circle().fill(Color.red))
                            .offset(x: 12, y: -12)
                    }

                    // Activity indicator when importing/exporting
                    if packageManager.isImporting || packageManager.isExporting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FFFC00")))
                            .scaleEffect(0.6)
                            .offset(x: -12, y: -12)
                    }
                }

                Text("Sync")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }
            .frame(width: 50, height: 50)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
        }
    }
}

// MARK: - Extended Data Package Button with Status

struct DataPackageStatusButton: View {
    @ObservedObject var packageManager: DataPackageManager
    @Binding var showDataPackages: Bool
    @State private var showQuickStatus = false

    var body: some View {
        VStack(spacing: 0) {
            // Main button
            Button(action: {
                showDataPackages = true
            }) {
                VStack(spacing: 4) {
                    ZStack {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#FFFC00"))

                        if !packageManager.packages.isEmpty {
                            Text("\(packageManager.packages.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(Color.red))
                                .offset(x: 12, y: -12)
                        }
                    }

                    Text("Sync")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
                .frame(width: 50, height: 50)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        showQuickStatus = true
                    }
            )

            // Quick status popup
            if showQuickStatus {
                quickStatusView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showQuickStatus = false
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showQuickStatus)
    }

    private var quickStatusView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Data Packages")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "#FFFC00"))

            Text("\(packageManager.packages.count) imported")
                .font(.system(size: 10))
                .foregroundColor(.white)

            Text(packageManager.formattedTotalStorage)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#999999"))

            if packageManager.isImporting {
                HStack(spacing: 4) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FFFC00")))
                        .scaleEffect(0.5)
                    Text("Importing...")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.9))
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Compact Inline Button

struct DataPackageInlineButton: View {
    @ObservedObject var packageManager: DataPackageManager
    @Binding var showDataPackages: Bool

    var body: some View {
        Button(action: {
            showDataPackages = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 14))

                if packageManager.packages.count > 0 {
                    Text("\(packageManager.packages.count)")
                        .font(.system(size: 12, weight: .medium))
                }

                if packageManager.isImporting || packageManager.isExporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FFFC00")))
                        .scaleEffect(0.5)
                }
            }
            .foregroundColor(Color(hex: "#FFFC00"))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.7))
            .cornerRadius(6)
        }
    }
}

// MARK: - Toolbar Item Button

struct DataPackageToolbarButton: View {
    @ObservedObject var packageManager: DataPackageManager
    @Binding var showDataPackages: Bool

    var body: some View {
        Button(action: {
            showDataPackages = true
        }) {
            ZStack {
                Image(systemName: "shippingbox")
                    .font(.system(size: 20))

                if !packageManager.packages.isEmpty {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Text("\(min(packageManager.packages.count, 9))")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 10, y: -10)
                }
            }
        }
        .foregroundColor(Color(hex: "#FFFC00"))
    }
}

// MARK: - Floating Action Button Style

struct DataPackageFAB: View {
    @ObservedObject var packageManager: DataPackageManager
    @Binding var showDataPackages: Bool
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            showDataPackages = true
        }) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#FFFC00"))
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.black)

                if !packageManager.packages.isEmpty {
                    Text("\(packageManager.packages.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Circle().fill(Color.red))
                        .offset(x: 20, y: -20)
                }

                if packageManager.isImporting || packageManager.isExporting {
                    Circle()
                        .trim(from: 0, to: packageManager.isImporting ? packageManager.importProgress : packageManager.exportProgress)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Preview

struct DataPackageButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(hex: "#1E1E1E")
                .ignoresSafeArea()

            VStack(spacing: 20) {
                DataPackageButton(
                    packageManager: DataPackageManager(),
                    showDataPackages: .constant(false)
                )

                DataPackageStatusButton(
                    packageManager: DataPackageManager(),
                    showDataPackages: .constant(false)
                )

                DataPackageInlineButton(
                    packageManager: DataPackageManager(),
                    showDataPackages: .constant(false)
                )

                DataPackageFAB(
                    packageManager: DataPackageManager(),
                    showDataPackages: .constant(false)
                )
            }
        }
    }
}
