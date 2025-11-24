//
//  AboutView.swift
//  OmniTAKMobile
//
//  About screen with app information
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo and Title
                    VStack(spacing: 16) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "#FFFC00"))

                        Text("OmniTAK Mobile")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(hex: "#FFFC00"))

                        Text("Version 1.3.4 (Build 3)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)

                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Text("OmniTAK Mobile is a modern iOS client for TAK (Team Awareness Kit) servers, providing real-time situational awareness and tactical communication capabilities.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .lineSpacing(4)

                        Text("Built with SwiftUI and designed to be compatible with ATAK, iTAK, WinTAK, and other TAK ecosystem applications.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .lineSpacing(4)
                    }
                    .padding()
                    .background(Color(hex: "#2A2A2A"))
                    .cornerRadius(12)

                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        FeatureItem(icon: "map.fill", title: "Tactical Mapping", description: "Real-time map with multiple layer types")
                        FeatureItem(icon: "antenna.radiowaves.left.and.right", title: "CoT Protocol", description: "Full Cursor-on-Target message support")
                        FeatureItem(icon: "person.3.fill", title: "Team Management", description: "Organize teams and track members")
                        FeatureItem(icon: "message.fill", title: "Team Chat", description: "GeoChat messaging integration")
                        FeatureItem(icon: "pencil.tip", title: "Drawing Tools", description: "Tactical overlays and annotations")
                        FeatureItem(icon: "square.dashed", title: "Geofencing", description: "Location-based alerts and boundaries")
                        FeatureItem(icon: "video.fill", title: "Video Streaming", description: "Live video feed support")
                        FeatureItem(icon: "arrow.down.doc.fill", title: "Offline Maps", description: "Download regions for offline use")
                    }
                    .padding()
                    .background(Color(hex: "#2A2A2A"))
                    .cornerRadius(12)

                    // Credits
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Credits")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Text("Developed by omni-TAK Team")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)

                        Text("Built with SwiftUI for iOS 15+")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)

                        Text("Uses Apple MapKit for mapping")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)

                        Divider()
                            .background(Color.gray.opacity(0.3))

                        Text("This software is provided as-is for tactical awareness and communication purposes. Always follow local laws and regulations regarding the use of tactical communication systems.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .italic()
                    }
                    .padding()
                    .background(Color(hex: "#2A2A2A"))
                    .cornerRadius(12)

                    // Links
                    VStack(spacing: 12) {
                        Button(action: {
                            // Open website
                        }) {
                            HStack {
                                Image(systemName: "globe")
                                Text("Visit Website")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .foregroundColor(.blue)
                        }

                        Button(action: {
                            // Open documentation
                        }) {
                            HStack {
                                Image(systemName: "book.fill")
                                Text("Documentation")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .foregroundColor(.blue)
                        }

                        Button(action: {
                            // Open GitHub
                        }) {
                            HStack {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                Text("Source Code")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color(hex: "#2A2A2A"))
                    .cornerRadius(12)

                    // Footer
                    VStack(spacing: 8) {
                        Text("Powered by omni-TAK")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#FFFC00"))

                        Text("2024 All Rights Reserved")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal)
            }
            .background(Color(hex: "#1E1E1E"))
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Feature Item

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#FFFC00"))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
    }
}
