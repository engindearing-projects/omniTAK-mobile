//
//  FirstTimeOnboarding.swift
//  OmniTAKMobile
//
//  Beautiful onboarding experience for first-time users
//

import SwiftUI

// MARK: - First Time Onboarding

struct FirstTimeOnboarding: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var showQuickConnect = false

    let pages = OnboardingPage.all

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Text("Skip")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Custom page indicator
                pageIndicator

                // Action button
                actionButton
            }
        }
        .fullScreenCover(isPresented: $showQuickConnect) {
            QuickConnectView()
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(currentPage == index ? Color(hex: "#FFFC00") : Color(hex: "#666666"))
                    .frame(width: currentPage == index ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
        .padding(.vertical, 24)
    }

    private var actionButton: some View {
        VStack(spacing: 12) {
            Button(action: {
                if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    showQuickConnect = true
                }
            }) {
                HStack {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                        .font(.system(size: 18, weight: .semibold))
                    if currentPage == pages.count - 1 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(hex: "#FFFC00"))
                .cornerRadius(14)
            }

            if currentPage > 0 {
                Button(action: {
                    withAnimation {
                        currentPage -= 1
                    }
                }) {
                    Text("Back")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 40)
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let features: [String]

    static let all: [OnboardingPage] = [
        OnboardingPage(
            icon: "antenna.radiowaves.left.and.right",
            title: "Welcome to OmniTAK",
            description: "Your powerful iOS client for Team Awareness Kit (TAK) servers. Connect, share, and collaborate in real-time.",
            color: Color(hex: "#FFFC00"),
            features: [
                "Real-time position sharing",
                "Secure communications",
                "Map-based awareness",
                "Multi-platform support"
            ]
        ),
        OnboardingPage(
            icon: "lock.shield.fill",
            title: "Secure & Certified",
            description: "OmniTAK supports certificate-based authentication for secure connections to TAK servers.",
            color: Color(hex: "#00FF00"),
            features: [
                "Client certificate support",
                "TLS/SSL encryption",
                "Keychain integration",
                "Automatic enrollment"
            ]
        ),
        OnboardingPage(
            icon: "bolt.circle.fill",
            title: "Quick & Easy Setup",
            description: "Get connected in seconds with our smart setup wizard. Multiple connection methods for every scenario.",
            color: Color(hex: "#00BFFF"),
            features: [
                "QR code scanning",
                "Auto-discovery",
                "Common presets",
                "Manual configuration"
            ]
        ),
        OnboardingPage(
            icon: "map.fill",
            title: "Ready to Connect?",
            description: "Let's get you connected to a TAK server. Choose the method that works best for you.",
            color: Color(hex: "#FF6B35"),
            features: [
                "Connect in < 30 seconds",
                "No technical knowledge needed",
                "Full ATAK compatibility",
                "Works with any TAK server"
            ]
        )
    ]
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(page.color.opacity(0.25))
                    .frame(width: 100, height: 100)

                Image(systemName: page.icon)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundColor(page.color)
            }

            // Title
            Text(page.title)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Description
            Text(page.description)
                .font(.system(size: 17))
                .foregroundColor(Color(hex: "#CCCCCC"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)

            // Features
            VStack(spacing: 14) {
                ForEach(page.features, id: \.self) { feature in
                    FeatureRow(text: feature, color: page.color)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
    }
}

struct FeatureRow: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white)

            Spacer()
        }
    }
}

// MARK: - Onboarding Manager

class OnboardingManager: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}

// MARK: - Quick Start Guide

struct QuickStartGuide: View {
    @Environment(\.dismiss) private var dismiss

    let guides = [
        QuickStartItem(
            icon: "qrcode.viewfinder",
            title: "Scan QR Code",
            description: "Fastest method - scan the enrollment QR from your TAK server admin",
            difficulty: "Easiest",
            time: "< 30 sec",
            color: Color(hex: "#00FF00")
        ),
        QuickStartItem(
            icon: "wifi.circle.fill",
            title: "Auto-Discover",
            description: "Find TAK servers on your local network automatically",
            difficulty: "Easy",
            time: "< 1 min",
            color: Color(hex: "#00BFFF")
        ),
        QuickStartItem(
            icon: "bolt.circle.fill",
            title: "Quick Setup",
            description: "Use presets for common TAK server configurations",
            difficulty: "Easy",
            time: "< 2 min",
            color: Color(hex: "#FF6B35")
        ),
        QuickStartItem(
            icon: "keyboard",
            title: "Manual Setup",
            description: "Full control - configure all connection parameters yourself",
            difficulty: "Advanced",
            time: "~3 min",
            color: Color(hex: "#9B59B6")
        )
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Color(hex: "#FFFC00"))

                            Text("Quick Start Guide")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)

                            Text("Choose the connection method that works best for your situation")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "#CCCCCC"))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 32)

                        // Guide items
                        VStack(spacing: 16) {
                            ForEach(guides, id: \.title) { guide in
                                QuickStartItemView(item: guide)
                            }
                        }
                        .padding(.horizontal, 20)

                        // Help section
                        helpSection
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
    }

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(Color(hex: "#FFFC00"))
                Text("Need Help?")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 12) {
                HelpLink(icon: "doc.text.fill", text: "Read the Documentation", url: "https://docs.omnitak.com")
                HelpLink(icon: "person.2.fill", text: "Contact Support", url: "mailto:support@omnitak.com")
                HelpLink(icon: "video.fill", text: "Watch Tutorial Videos", url: "https://youtube.com/@omnitak")
            }
        }
        .padding(20)
        .background(Color(white: 0.1))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

struct QuickStartItem {
    let icon: String
    let title: String
    let description: String
    let difficulty: String
    let time: String
    let color: Color
}

struct QuickStartItemView: View {
    let item: QuickStartItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 28))
                    .foregroundColor(item.color)
                    .frame(width: 56, height: 56)
                    .background(item.color.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    HStack(spacing: 12) {
                        Label(item.difficulty, systemImage: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(item.color)

                        Label(item.time, systemImage: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                    }
                }

                Spacer()
            }

            Text(item.description)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#CCCCCC"))
                .lineSpacing(2)
        }
        .padding(16)
        .background(Color(white: 0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(item.color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct HelpLink: View {
    let icon: String
    let text: String
    let url: String

    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#FFFC00"))
                    .frame(width: 28)

                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#666666"))
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FirstTimeOnboarding_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FirstTimeOnboarding()
            QuickStartGuide()
        }
        .preferredColorScheme(.dark)
    }
}
#endif
