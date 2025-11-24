//
//  PhotoPickerView.swift
//  OmniTAKMobile
//
//  SwiftUI photo picker with camera and library support, preview, and compression options
//

import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - Photo Picker View

struct PhotoPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var tempImage: UIImage?
    @State private var compressionQuality: CompressionQuality = .medium
    @State private var estimatedSize: String = ""
    @State private var showCameraPermissionAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Preview area
                if let image = tempImage {
                    // Image preview with options
                    VStack(spacing: 16) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 400)
                            .cornerRadius(12)
                            .shadow(radius: 4)

                        // Image info
                        VStack(spacing: 8) {
                            Text("Original: \(Int(image.size.width)) x \(Int(image.size.height))")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Text("Estimated size: \(estimatedSize)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        // Compression quality selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Compression Quality")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Picker("Quality", selection: $compressionQuality) {
                                Text("Low (smaller file)").tag(CompressionQuality.low)
                                Text("Medium").tag(CompressionQuality.medium)
                                Text("High (better quality)").tag(CompressionQuality.high)
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: compressionQuality) { _ in
                                updateEstimatedSize()
                            }
                        }
                        .padding(.horizontal)

                        Spacer()

                        // Action buttons
                        HStack(spacing: 20) {
                            Button(action: {
                                tempImage = nil
                            }) {
                                Label("Remove", systemImage: "trash")
                                    .foregroundColor(.red)
                            }

                            Button(action: {
                                selectedImage = tempImage
                                dismiss()
                            }) {
                                Label("Use Photo", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                } else {
                    // Source selection
                    VStack(spacing: 24) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)

                        Text("Select Photo Source")
                            .font(.title2)
                            .fontWeight(.semibold)

                        VStack(spacing: 16) {
                            // Camera option
                            Button(action: {
                                checkCameraPermission()
                            }) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 24))
                                    Text("Take Photo")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .foregroundColor(.primary)

                            // Photo library option
                            Button(action: {
                                showImagePicker = true
                            }) {
                                HStack {
                                    Image(systemName: "photo.stack.fill")
                                        .font(.system(size: 24))
                                    Text("Choose from Library")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .foregroundColor(.primary)
                        }
                        .padding(.horizontal)

                        Spacer()
                    }
                    .padding(.top, 40)
                }
            }
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                PHPickerViewRepresentable(image: $tempImage)
                    .onDisappear {
                        updateEstimatedSize()
                    }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $tempImage)
                    .onDisappear {
                        updateEstimatedSize()
                    }
            }
            .alert("Camera Access Required", isPresented: $showCameraPermissionAlert) {
                Button("Open Settings", role: .none) {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please allow camera access in Settings to take photos.")
            }
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraPermissionAlert = true
        @unknown default:
            break
        }
    }

    private func updateEstimatedSize() {
        guard let image = tempImage else {
            estimatedSize = ""
            return
        }

        // Estimate compressed size
        if let data = PhotoAttachmentService.shared.compressImage(image, quality: compressionQuality) {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            estimatedSize = formatter.string(fromByteCount: Int64(data.count))
        }
    }
}

// MARK: - PHPicker SwiftUI Wrapper (iOS 14+)

struct PHPickerViewRepresentable: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerViewRepresentable

        init(_ parent: PHPickerViewRepresentable) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                if let error = error {
                    print("PHPicker: Error loading image: \(error)")
                    return
                }

                DispatchQueue.main.async {
                    self?.parent.image = image as? UIImage
                }
            }
        }
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Full Screen Image Viewer

struct FullScreenImageView: View {
    let image: UIImage
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale < 1.0 {
                                withAnimation {
                                    scale = 1.0
                                    lastScale = 1.0
                                }
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        if scale > 1.0 {
                            scale = 1.0
                            lastScale = 1.0
                        } else {
                            scale = 2.0
                            lastScale = 2.0
                        }
                    }
                }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .statusBar(hidden: true)
    }
}

// MARK: - Image Loading View

struct AsyncImageView: View {
    let path: String
    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ProgressView()
                    .frame(width: 200, height: 150)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                    .frame(width: 200, height: 150)
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        // Check cache first
        if let cached = ImageCache.shared.get(path) {
            self.image = cached
            self.isLoading = false
            return
        }

        // Load from disk
        DispatchQueue.global(qos: .userInitiated).async {
            if let loadedImage = UIImage(contentsOfFile: path) {
                ImageCache.shared.set(loadedImage, for: path)
                DispatchQueue.main.async {
                    self.image = loadedImage
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}
