//
//  PhotoAttachmentService.swift
//  OmniTAKMobile
//
//  Service for compressing, storing, and managing photo attachments for chat
//

import Foundation
import UIKit
import SwiftUI

class PhotoAttachmentService: ObservableObject {
    static let shared = PhotoAttachmentService()

    // MARK: - Configuration

    private let maxImageSizeBytes = 1_000_000 // 1MB max for transmission
    private let thumbnailSize = CGSize(width: 200, height: 200)
    private let maxImageDimension: CGFloat = 1920 // Max width or height
    private let jpegCompressionQuality: CGFloat = 0.7

    private let fileManager = FileManager.default
    private var attachmentsDirectory: URL?
    private var thumbnailsDirectory: URL?

    // MARK: - Initialization

    private init() {
        setupDirectories()
    }

    private func setupDirectories() {
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("PhotoAttachmentService: Failed to get documents directory")
            return
        }

        // Create attachments directory
        attachmentsDirectory = documentsPath.appendingPathComponent("ChatAttachments", isDirectory: true)
        if let attachmentsDir = attachmentsDirectory {
            try? fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
        }

        // Create thumbnails directory
        thumbnailsDirectory = documentsPath.appendingPathComponent("ChatThumbnails", isDirectory: true)
        if let thumbnailsDir = thumbnailsDirectory {
            try? fileManager.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
        }

        print("PhotoAttachmentService: Directories initialized")
    }

    // MARK: - Image Processing

    /// Compress and resize image for network transmission
    func compressImage(_ image: UIImage, quality: CompressionQuality = .medium) -> Data? {
        var currentImage = image

        // Resize if too large
        let maxDimension = maxImageDimension
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scale = maxDimension / max(image.size.width, image.size.height)
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            currentImage = resizeImage(image, to: newSize) ?? image
        }

        // Compress to JPEG
        let compressionQuality: CGFloat
        switch quality {
        case .low:
            compressionQuality = 0.5
        case .medium:
            compressionQuality = 0.7
        case .high:
            compressionQuality = 0.85
        }

        var imageData = currentImage.jpegData(compressionQuality: compressionQuality)

        // If still too large, reduce quality further
        var currentQuality = compressionQuality
        while let data = imageData, data.count > maxImageSizeBytes && currentQuality > 0.1 {
            currentQuality -= 0.1
            imageData = currentImage.jpegData(compressionQuality: currentQuality)
        }

        // If still too large, resize more aggressively
        if let data = imageData, data.count > maxImageSizeBytes {
            let scaleFactor = sqrt(Double(maxImageSizeBytes) / Double(data.count))
            let newSize = CGSize(
                width: currentImage.size.width * scaleFactor,
                height: currentImage.size.height * scaleFactor
            )
            if let resizedImage = resizeImage(currentImage, to: newSize) {
                imageData = resizedImage.jpegData(compressionQuality: 0.6)
            }
        }

        return imageData
    }

    /// Generate thumbnail for chat list display
    func generateThumbnail(from image: UIImage) -> UIImage? {
        return resizeImage(image, to: thumbnailSize)
    }

    /// Resize image to specific size maintaining aspect ratio
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        let aspectWidth = size.width / image.size.width
        let aspectHeight = size.height / image.size.height
        let aspectRatio = min(aspectWidth, aspectHeight)

        let newSize = CGSize(
            width: image.size.width * aspectRatio,
            height: image.size.height * aspectRatio
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Storage

    /// Save image to local storage and return paths
    func saveImage(_ image: UIImage, for messageId: String) -> (localPath: String, thumbnailPath: String)? {
        guard let attachmentsDir = attachmentsDirectory,
              let thumbnailsDir = thumbnailsDirectory else {
            print("PhotoAttachmentService: Directories not initialized")
            return nil
        }

        // Compress and save main image
        guard let imageData = compressImage(image) else {
            print("PhotoAttachmentService: Failed to compress image")
            return nil
        }

        let imagePath = attachmentsDir.appendingPathComponent("\(messageId).jpg")
        do {
            try imageData.write(to: imagePath)
        } catch {
            print("PhotoAttachmentService: Failed to save image: \(error)")
            return nil
        }

        // Generate and save thumbnail
        guard let thumbnail = generateThumbnail(from: image),
              let thumbnailData = thumbnail.jpegData(compressionQuality: 0.6) else {
            print("PhotoAttachmentService: Failed to generate thumbnail")
            return nil
        }

        let thumbnailPath = thumbnailsDir.appendingPathComponent("\(messageId)_thumb.jpg")
        do {
            try thumbnailData.write(to: thumbnailPath)
        } catch {
            print("PhotoAttachmentService: Failed to save thumbnail: \(error)")
            return nil
        }

        print("PhotoAttachmentService: Saved image (\(imageData.count) bytes) and thumbnail for message \(messageId)")
        return (imagePath.path, thumbnailPath.path)
    }

    /// Load image from local storage
    func loadImage(from path: String) -> UIImage? {
        return UIImage(contentsOfFile: path)
    }

    /// Load thumbnail from local storage
    func loadThumbnail(from path: String) -> UIImage? {
        return UIImage(contentsOfFile: path)
    }

    /// Convert image data to base64 string for XML embedding
    func imageToBase64(_ imageData: Data) -> String {
        return imageData.base64EncodedString()
    }

    /// Convert base64 string back to image data
    func base64ToImageData(_ base64String: String) -> Data? {
        return Data(base64Encoded: base64String)
    }

    /// Create ImageAttachment from UIImage
    func createImageAttachment(from image: UIImage, messageId: String) -> ImageAttachment? {
        guard let paths = saveImage(image, for: messageId) else {
            return nil
        }

        // Load saved data to get actual size
        guard let savedData = try? Data(contentsOf: URL(fileURLWithPath: paths.localPath)) else {
            return nil
        }

        let filename = "\(messageId).jpg"

        // For smaller images, also generate base64 for inline transmission
        var base64Data: String? = nil
        if savedData.count < 500_000 { // Under 500KB, include base64
            base64Data = imageToBase64(savedData)
        }

        return ImageAttachment(
            id: messageId,
            filename: filename,
            mimeType: "image/jpeg",
            fileSize: savedData.count,
            localPath: paths.localPath,
            thumbnailPath: paths.thumbnailPath,
            base64Data: base64Data,
            remoteURL: nil
        )
    }

    // MARK: - Cleanup

    /// Delete attachment files for a specific message
    func deleteAttachment(for messageId: String) {
        guard let attachmentsDir = attachmentsDirectory,
              let thumbnailsDir = thumbnailsDirectory else {
            return
        }

        let imagePath = attachmentsDir.appendingPathComponent("\(messageId).jpg")
        let thumbnailPath = thumbnailsDir.appendingPathComponent("\(messageId)_thumb.jpg")

        try? fileManager.removeItem(at: imagePath)
        try? fileManager.removeItem(at: thumbnailPath)

        print("PhotoAttachmentService: Deleted attachments for message \(messageId)")
    }

    /// Clean up old attachments beyond a certain age
    func cleanupOldAttachments(olderThan days: Int) {
        guard let attachmentsDir = attachmentsDirectory,
              let thumbnailsDir = thumbnailsDirectory else {
            return
        }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var deletedCount = 0

        // Clean up attachments
        if let contents = try? fileManager.contentsOfDirectory(at: attachmentsDir, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for fileURL in contents {
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let modDate = attributes[.modificationDate] as? Date,
                   modDate < cutoffDate {
                    try? fileManager.removeItem(at: fileURL)
                    deletedCount += 1
                }
            }
        }

        // Clean up thumbnails
        if let contents = try? fileManager.contentsOfDirectory(at: thumbnailsDir, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for fileURL in contents {
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let modDate = attributes[.modificationDate] as? Date,
                   modDate < cutoffDate {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        }

        if deletedCount > 0 {
            print("PhotoAttachmentService: Cleaned up \(deletedCount) old attachments")
        }
    }

    /// Get total storage size used by attachments
    func getStorageUsed() -> Int64 {
        var totalSize: Int64 = 0

        if let attachmentsDir = attachmentsDirectory,
           let contents = try? fileManager.contentsOfDirectory(at: attachmentsDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for fileURL in contents {
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            }
        }

        if let thumbnailsDir = thumbnailsDirectory,
           let contents = try? fileManager.contentsOfDirectory(at: thumbnailsDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for fileURL in contents {
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            }
        }

        return totalSize
    }

    /// Format storage size for display
    func formatStorageSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Compression Quality

enum CompressionQuality {
    case low
    case medium
    case high
}

// MARK: - Image Cache

class ImageCache {
    static let shared = ImageCache()

    private var cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 50 // Max 50 images in memory
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB max
    }

    func set(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // Approximate memory cost
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func get(_ key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }

    func remove(_ key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    func clearAll() {
        cache.removeAllObjects()
    }
}
