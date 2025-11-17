//
//  SHARED_INTERFACES.swift
//  OmniTAKMobile
//
//  Shared protocols and interfaces for cross-feature communication
//  NOTE: Many types have been moved to their respective feature files to avoid redeclaration conflicts
//

import Foundation

// MARK: - Notification Names
// These can be used across all features for loose coupling

extension Notification.Name {
    // Certificate Enrollment
    static let certificateEnrolled = Notification.Name("com.omnitak.certificateEnrolled")
    static let certificateExpiring = Notification.Name("com.omnitak.certificateExpiring")

    // CoT Events
    static let cotEventReceived = Notification.Name("com.omnitak.cotEventReceived")
    static let cotPositionUpdate = Notification.Name("com.omnitak.cotPositionUpdate")
    static let cotEmergencyAlert = Notification.Name("com.omnitak.cotEmergencyAlert")

    // Emergency Beacon
    static let emergencyActivated = Notification.Name("com.omnitak.emergencyActivated")
    static let emergencyCancelled = Notification.Name("com.omnitak.emergencyCancelled")
    static let emergencyBroadcast = Notification.Name("com.omnitak.emergencyBroadcast")

    // KML Import
    static let kmlFileImported = Notification.Name("com.omnitak.kmlFileImported")
    static let kmlLayerToggled = Notification.Name("com.omnitak.kmlLayerToggled")

    // Photo Sharing
    static let photoAttached = Notification.Name("com.omnitak.photoAttached")
    static let photoReceived = Notification.Name("com.omnitak.photoReceived")

    // Map Updates
    static let mapOverlaysUpdated = Notification.Name("com.omnitak.mapOverlaysUpdated")
    static let mapAnnotationsUpdated = Notification.Name("com.omnitak.mapAnnotationsUpdated")
}

// MARK: - Feature Status Tracking

enum FeatureStatus {
    case notConfigured
    case initializing
    case ready
    case error(String)
}

// MARK: - Coordination Notes
/*
 This file serves as a coordination point for OmniTAK features.

 Type definitions are kept in their respective feature files:
 - EmergencyType -> EmergencyBeaconService.swift
 - CoTCategory -> CoTFilterModel.swift
 - AttachmentType -> ChatModels.swift
 - CompressionQuality -> PhotoAttachmentService.swift
 - ImageAttachment -> ChatModels.swift

 Use Notification.Name extensions above for cross-feature communication.
 */
