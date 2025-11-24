//
//  CertificateSelectionView.swift
//  OmniTAKMobile
//
//  Certificate selection view for Add Server dialog
//  Allows selecting existing certificates or creating new ones
//

import SwiftUI

// MARK: - Certificate Selection View

struct CertificateSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var certificateManager = CertificateManager.shared

    @State private var showImportSheet = false
    @State private var showEnrollmentView = false
    @State private var selectedCertificateId: UUID?

    var onSelect: (UUID, String) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    if certificateManager.certificates.isEmpty {
                        emptyStateView
                    } else {
                        certificateListView
                    }
                }
            }
            .navigationTitle("Select Certificate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showImportSheet = true }) {
                            Label("Import from File", systemImage: "doc.badge.plus")
                        }

                        Button(action: { showEnrollmentView = true }) {
                            Label("Enroll from Server", systemImage: "qrcode.viewfinder")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(hex: "#FFFC00"))
                            .font(.system(size: 20))
                    }
                }
            }
            .sheet(isPresented: $showImportSheet) {
                CertificateImportSheet(onComplete: handleCertificateAdded)
            }
            .sheet(isPresented: $showEnrollmentView) {
                CertificateEnrollmentView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "#CCCCCC"))

            Text("No Certificates")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Text("Import a certificate file or enroll with a TAK server to secure your connection")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#CCCCCC"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                Button(action: { showImportSheet = true }) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Import from File")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#FFFC00"))
                    .cornerRadius(12)
                }

                Button(action: { showEnrollmentView = true }) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                        Text("Enroll from Server")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#FFFC00"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(white: 0.15))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)

            Spacer()
        }
    }

    // MARK: - Certificate List

    private var certificateListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(certificateManager.certificates) { certificate in
                    CertificateSelectionRow(
                        certificate: certificate,
                        isSelected: selectedCertificateId == certificate.id,
                        onSelect: {
                            selectedCertificateId = certificate.id
                            onSelect(certificate.id, certificate.name)
                            dismiss()
                        }
                    )
                }
            }
            .padding(16)
        }
    }

    // MARK: - Handlers

    private func handleCertificateAdded(_ certificateId: UUID, _ name: String) {
        onSelect(certificateId, name)
        dismiss()
    }
}

// MARK: - Certificate Selection Row

struct CertificateSelectionRow: View {
    let certificate: TAKCertificate
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: statusIcon)
                        .font(.system(size: 20))
                        .foregroundColor(statusColor)
                }

                // Certificate info
                VStack(alignment: .leading, spacing: 4) {
                    Text(certificate.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(certificate.username)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(certificate.serverURL)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#999999"))
                            .lineLimit(1)

                        if certificate.isExpired {
                            Text("• EXPIRED")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                        } else if let expiry = certificate.expiryDate {
                            Text("• Expires \(formatDate(expiry))")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#999999"))
                        }
                    }
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
            .padding(16)
            .background(isSelected ? Color(hex: "#FFFC00").opacity(0.1) : Color(white: 0.12))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color(hex: "#FFFC00") : statusColor.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var statusColor: Color {
        if certificate.isExpired {
            return .red
        } else if !certificate.isValid {
            return .orange
        } else {
            return Color(hex: "#00FF00")
        }
    }

    private var statusIcon: String {
        if certificate.isExpired {
            return "exclamationmark.triangle.fill"
        } else if !certificate.isValid {
            return "exclamationmark.circle.fill"
        } else {
            return "checkmark.shield.fill"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#if DEBUG
struct CertificateSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        CertificateSelectionView(onSelect: { id, name in
            print("Selected: \(name) - \(id)")
        })
        .preferredColorScheme(.dark)
    }
}
#endif
