//
//  ImprovedErrorDialog.swift
//  OmniTAKMobile
//
//  User-friendly error dialog with troubleshooting steps
//

import SwiftUI

// MARK: - Improved Error Dialog

struct ImprovedErrorDialog: View {
    let title: String
    let message: String
    let troubleshootingSteps: [String]
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.red)

                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(20)
                .background(Color(white: 0.15))

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Error message
                        if !message.isEmpty {
                            Text(message)
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "#CCCCCC"))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Troubleshooting steps
                        if !troubleshootingSteps.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                        .foregroundColor(Color(hex: "#FFFC00"))
                                    Text("Troubleshooting Steps")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(troubleshootingSteps.indices, id: \.self) { index in
                                        let step = troubleshootingSteps[index]
                                        if step.isEmpty {
                                            Spacer()
                                                .frame(height: 4)
                                        } else if step.hasPrefix("•") || step.hasPrefix("1.") || step.hasPrefix("2.") || step.hasPrefix("3.") || step.hasPrefix("4.") {
                                            Text(step)
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hex: "#AAAAAA"))
                                                .fixedSize(horizontal: false, vertical: true)
                                                .padding(.leading, 8)
                                        } else {
                                            Text(step)
                                                .font(.system(size: 14, weight: step.hasSuffix(":") ? .semibold : .regular))
                                                .foregroundColor(step.hasSuffix(":") ? .white : Color(hex: "#AAAAAA"))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                                .padding(.leading, 4)
                            }
                            .padding(16)
                            .background(Color(white: 0.08))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#FFFC00").opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(20)
                }
                .frame(maxHeight: 400)

                // Dismiss button
                Button(action: onDismiss) {
                    Text("OK")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#FFFC00"))
                        .cornerRadius(12)
                }
                .padding(20)
            }
            .frame(maxWidth: 500)
            .background(Color(white: 0.12))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.5), radius: 20)
            .padding(40)
        }
    }
}

// MARK: - Simple Error Alert (for basic errors)

struct SimpleErrorAlert: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Icon and title
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.red)

                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }

                // Message
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#CCCCCC"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)

                // Dismiss button
                Button(action: onDismiss) {
                    Text("OK")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#FFFC00"))
                        .cornerRadius(12)
                }
            }
            .padding(30)
            .frame(maxWidth: 400)
            .background(Color(white: 0.12))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.5), radius: 20)
            .padding(40)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ImprovedErrorDialog_Previews: PreviewProvider {
    static var previews: some View {
        ImprovedErrorDialog(
            title: "Connection Failed",
            message: "The server returned a web page instead of the expected response. This usually means you're connecting to the wrong port.",
            troubleshootingSteps: [
                "You may be connecting to the wrong port:",
                "• Port 8089 - Streaming CoT (TLS, binary protocol)",
                "• Port 8446 - Certificate enrollment (HTTPS API)",
                "• Port 8443 - Web interface (not for app connections)",
                "",
                "Try these steps:",
                "1. Verify the correct port with your server admin",
                "2. For enrollment, use port 8446",
                "3. For streaming, use port 8089 with TLS enabled",
                "4. Check if the server's enrollment API is enabled"
            ],
            onDismiss: {}
        )
        .preferredColorScheme(.dark)
    }
}
#endif
