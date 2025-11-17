//
//  KMLImportView.swift
//  OmniTAKMobile
//
//  SwiftUI interface for importing and managing KML/KMZ files
//

import SwiftUI
import UniformTypeIdentifiers

struct KMLImportView: View {
    @ObservedObject var kmlManager: KMLOverlayManager
    @Binding var isPresented: Bool
    @State private var showFilePicker = false
    @State private var showDeleteConfirmation = false
    @State private var documentToDelete: UUID?

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Import Button
                    importButton
                        .padding()

                    // Error message
                    if let error = kmlManager.lastError {
                        errorBanner(error)
                    }

                    // Loading indicator
                    if kmlManager.isLoading {
                        loadingView
                    }

                    // Document list
                    if kmlManager.documents.isEmpty {
                        emptyStateView
                    } else {
                        documentList
                    }
                }
            }
            .navigationTitle("KML Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showFilePicker) {
            DocumentPicker(kmlManager: kmlManager)
        }
        .alert("Delete File", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let id = documentToDelete {
                    kmlManager.deleteDocument(id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this KML file? This action cannot be undone.")
        }
    }

    private var importButton: some View {
        Button(action: {
            showFilePicker = true
        }) {
            HStack {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 20))
                Text("Import KML/KMZ File")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(hex: "#FFFC00"))
            .cornerRadius(10)
        }
        .disabled(kmlManager.isLoading)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.red)
            Spacer()
            Button(action: {
                kmlManager.lastError = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    private var loadingView: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FFFC00")))
            Text("Importing file...")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#3A3A3A"))

            Text("No KML Files")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text("Import KML or KMZ files to display geospatial data on the map")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#999999"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var documentList: some View {
        List {
            ForEach(kmlManager.documents) { document in
                KMLDocumentRow(
                    document: document,
                    statistics: kmlManager.statistics(for: document),
                    onToggleVisibility: {
                        kmlManager.toggleVisibility(for: document.id)
                    },
                    onDelete: {
                        documentToDelete = document.id
                        showDeleteConfirmation = true
                    }
                )
                .listRowBackground(Color(hex: "#2A2A2A"))
            }
        }
        .listStyle(PlainListStyle())
        .background(Color(hex: "#1E1E1E"))
    }
}

// MARK: - Document Row

struct KMLDocumentRow: View {
    let document: KMLDocument
    let statistics: String
    let onToggleVisibility: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Visibility toggle
                Button(action: onToggleVisibility) {
                    Image(systemName: document.isVisible ? "eye.fill" : "eye.slash.fill")
                        .foregroundColor(document.isVisible ? Color(hex: "#FFFC00") : .gray)
                        .frame(width: 30)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(document.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(document.fileName)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#999999"))
                        .lineLimit(1)
                }

                Spacer()

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: 30)
                }
            }

            HStack {
                // Statistics
                Label(statistics, systemImage: "square.3.layers.3d")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#CCCCCC"))

                Spacer()

                // Import date
                Text("Imported: \(formatDate(document.importDate))")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#666666"))
            }

            if let description = document.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#AAAAAA"))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let kmlManager: KMLOverlayManager

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Define supported types
        let kmlType = UTType(filenameExtension: "kml") ?? UTType.xml
        let kmzType = UTType(filenameExtension: "kmz") ?? UTType.archive

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [kmlType, kmzType])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true

        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(kmlManager: kmlManager)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let kmlManager: KMLOverlayManager

        init(kmlManager: KMLOverlayManager) {
            self.kmlManager = kmlManager
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                DispatchQueue.main.async {
                    self.kmlManager.lastError = "Unable to access the selected file"
                }
                return
            }

            // Copy file to app sandbox first
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)

            do {
                // Remove existing temp file if any
                try? FileManager.default.removeItem(at: tempURL)

                // Copy to temp
                try FileManager.default.copyItem(at: url, to: tempURL)

                // Import from temp
                Task {
                    await kmlManager.importKMLFile(from: tempURL)

                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempURL)
                }
            } catch {
                DispatchQueue.main.async {
                    self.kmlManager.lastError = "Failed to copy file: \(error.localizedDescription)"
                }
            }

            url.stopAccessingSecurityScopedResource()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // User cancelled
        }
    }
}

// MARK: - Compact KML Button for Main UI

struct KMLImportButton: View {
    @ObservedObject var kmlManager: KMLOverlayManager
    @Binding var showKMLImport: Bool

    var body: some View {
        Button(action: {
            showKMLImport = true
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: "map.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#FFFC00"))

                    if !kmlManager.documents.isEmpty {
                        Text("\(kmlManager.documents.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Circle().fill(Color.red))
                            .offset(x: 12, y: -12)
                    }
                }

                Text("KML")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }
            .frame(width: 50, height: 50)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
        }
    }
}

// MARK: - Preview

struct KMLImportView_Previews: PreviewProvider {
    static var previews: some View {
        KMLImportView(
            kmlManager: KMLOverlayManager(),
            isPresented: .constant(true)
        )
    }
}
