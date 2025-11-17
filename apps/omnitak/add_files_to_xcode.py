#!/usr/bin/env python3
"""
Script to add new Swift files to OmniTAKMobile Xcode project
"""
import os
import uuid
import re

# Files to add
new_files = [
    # Previous files
    "WaypointModels.swift",
    "WaypointManager.swift",
    "NavigationService.swift",
    "WaypointListView.swift",
    "CompassOverlay.swift",
    "CompassOverlayView.swift",
    "ContactListView.swift",
    "ContactDetailView.swift",
    "CoordinateDisplayView.swift",
    "ScaleBarView.swift",
    # Coordination
    "SHARED_INTERFACES.swift",
    # Certificate Enrollment
    "CertificateEnrollmentService.swift",
    "CertificateEnrollmentView.swift",
    # CoT Receiving
    "CoTMessageParser.swift",
    "CoTEventHandler.swift",
    # Emergency Beacon
    "EmergencyBeaconService.swift",
    "EmergencyBeaconView.swift",
    # KML Import
    "KMLParser.swift",
    "KMZHandler.swift",
    "KMLOverlayManager.swift",
    "KMLImportView.swift",
    "KMLMapIntegration.swift",
    # Photo Sharing
    "PhotoAttachmentService.swift",
    "PhotoPickerView.swift",
    # NEW: Data Package Management
    "DataPackageModels.swift",
    "DataPackageManager.swift",
    "DataPackageView.swift",
    "DataPackageButton.swift",
    "OfflineTileCache.swift",
    # NEW: Video Streaming
    "VideoStreamModels.swift",
    "VideoStreamService.swift",
    "VideoPlayerView.swift",
    "VideoFeedListView.swift",
    "VideoStreamButton.swift",
    "VideoMapOverlay.swift",
    # NEW: Track Recording
    "TrackModels.swift",
    "TrackRecordingService.swift",
    "TrackOverlayRenderer.swift",
    "TrackRecordingView.swift",
    "TrackListView.swift",
    "TrackRecordingButton.swift",
    # NEW: Point Dropper / Hostile Marking
    "PointMarkerModels.swift",
    "PointDropperService.swift",
    "MarkerCoTGenerator.swift",
    "SALUTEReportView.swift",
    "PointDropperView.swift",
    "MarkerAnnotationView.swift",
    # NEW: Measurement Tools
    "MeasurementModels.swift",
    "MeasurementCalculator.swift",
    "MeasurementManager.swift",
    "MeasurementOverlay.swift",
    "MeasurementToolView.swift",
    "MeasurementButton.swift",
    "RangeRingConfigView.swift",
    "MeasurementService.swift",
    # NEW: Radial Menu
    "RadialMenuModels.swift",
    "RadialMenuItemView.swift",
    "RadialMenuView.swift",
    "RadialMenuGestureHandler.swift",
    "RadialMenuAnimations.swift",
    "RadialMenuPresets.swift",
    "RadialMenuMapCoordinator.swift",
    "MapContextMenus.swift",
    "RadialMenuActionExecutor.swift",
    "RadialMenuMapOverlay.swift",
    "RadialMenuButton.swift",
    # NEW: Critical Feature UI Views
    "ChatCoTGenerator.swift",
    "TeamManagementView.swift",
    "RoutePlanningView.swift",
    "GeofenceManagementView.swift",
    # NEW: Critical Feature Services & Models
    "TeamModels.swift",
    "TeamService.swift",
    "RouteModels.swift",
    "RoutePlanningService.swift",
    "GeofenceModels.swift",
    "GeofenceService.swift",
    "OfflineMapModels.swift",
    # NEW: Storage Managers
    "TeamStorageManager.swift",
    "RouteStorageManager.swift",
    "ChatStorageManager.swift",
    "GeofenceManager.swift",
    "GeofenceCoTGenerator.swift",
    "TeamCoTGenerator.swift",
    # NEW: Additional Views
    "SettingsView.swift",
    "PluginsListView.swift",
    "AboutView.swift",
    # NEW: Position Broadcasting (PLI/SA)
    "PositionBroadcastService.swift",
    "PositionBroadcastView.swift",
    # NEW: MEDEVAC 9-Line Request
    "MEDEVACModels.swift",
    "MEDEVACRequestView.swift",
    # NEW: 9-Line CAS Request
    "CASRequestModels.swift",
    "CASRequestView.swift",
    # NEW: SPOTREP Tactical Reporting
    "SPOTREPModels.swift",
    "SPOTREPView.swift",
    # NEW: Bloodhound BFT
    "BloodhoundService.swift",
    "BloodhoundView.swift",
    # NEW: MGRS Grid System
    "MGRSConverter.swift",
    "MGRSGridOverlay.swift",
    # NEW: MIL-STD-2525 Symbols
    "MilStd2525Symbols.swift",
    "MilStd2525SymbolView.swift",
    # NEW: Elevation Profile
    "ElevationProfileModels.swift",
    "ElevationProfileService.swift",
    "ElevationProfileView.swift",
    # NEW: Line of Sight
    "LineOfSightModels.swift",
    "LineOfSightService.swift",
    "LineOfSightView.swift",
    # NEW: Echelon/Unit Hierarchy
    "EchelonModels.swift",
    "EchelonService.swift",
    "EchelonHierarchyView.swift",
    # NEW: Mission Package Sync
    "MissionPackageModels.swift",
    "MissionPackageSyncService.swift",
    "MissionPackageSyncView.swift",
    # NEW: ATAK UI/UX Improvements
    "QuickActionToolbar.swift",
    "MapCursorMode.swift",
    "MilStd2525MarkerView.swift",
    "BreadcrumbTrailService.swift",
    "BreadcrumbTrailOverlay.swift",
    "RangeBearingService.swift",
    "RangeBearingOverlay.swift",
    "MapOverlayCoordinator.swift",
    "MapStateManager.swift",
    "MGRSGridToggleView.swift",
    "IntegratedMapView.swift",
    "MapViewIntegrationExample.swift",
]

project_dir = "/Users/iesouskurios/omni-BASE/apps/omnitak"
project_file = f"{project_dir}/OmniTAKMobile.xcodeproj/project.pbxproj"

def generate_uuid():
    """Generate a unique 24-character hex ID for Xcode"""
    return uuid.uuid4().hex[:24].upper()

def backup_project():
    """Create a backup of the project file"""
    import shutil
    backup_file = f"{project_file}.backup"
    shutil.copy2(project_file, backup_file)
    print(f"✅ Created backup: {backup_file}")
    return backup_file

def add_files_to_project():
    """Add Swift files to Xcode project"""

    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()

    # Generate UUIDs for each file (need 2 per file: fileRef and buildFile)
    file_refs = {}
    build_files = {}

    for filename in new_files:
        file_refs[filename] = generate_uuid()
        build_files[filename] = generate_uuid()

    # Find the PBXFileReference section
    file_ref_section = re.search(r'(/\* Begin PBXFileReference section \*/.*?/\* End PBXFileReference section \*/)', content, re.DOTALL)

    if not file_ref_section:
        print("❌ Could not find PBXFileReference section")
        return False

    # Find the PBXSourcesBuildPhase section
    sources_section = re.search(r'(/\* Begin PBXSourcesBuildPhase section \*/.*?/\* End PBXSourcesBuildPhase section \*/)', content, re.DOTALL)

    if not sources_section:
        print("❌ Could not find PBXSourcesBuildPhase section")
        return False

    # Find the PBXGroup section for OmniTAKMobile
    group_section = re.search(r'(/\* Begin PBXGroup section \*/.*?/\* End PBXGroup section \*/)', content, re.DOTALL)

    if not group_section:
        print("❌ Could not find PBXGroup section")
        return False

    # Create new file reference entries
    new_file_refs = []
    for filename in new_files:
        file_ref_id = file_refs[filename]
        entry = f'\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};\n'
        new_file_refs.append(entry)

    # Create new build file entries
    new_build_files = []
    for filename in new_files:
        build_file_id = build_files[filename]
        file_ref_id = file_refs[filename]
        entry = f'\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};\n'
        new_build_files.append(entry)

    # Insert file references
    file_ref_end = file_ref_section.end() - len("/* End PBXFileReference section */")
    new_content = content[:file_ref_end] + ''.join(new_file_refs) + content[file_ref_end:]

    # Find and insert build files (in PBXBuildFile section)
    build_file_section = re.search(r'(/\* Begin PBXBuildFile section \*/.*?/\* End PBXBuildFile section \*/)', new_content, re.DOTALL)
    if build_file_section:
        build_file_end = build_file_section.end() - len("/* End PBXBuildFile section */")
        new_content = new_content[:build_file_end] + ''.join(new_build_files) + new_content[build_file_end:]

    # Find the OmniTAKMobile group and add file references
    # Look for the children array in the OmniTAKMobile group
    omnitak_group = re.search(r'([A-F0-9]{24}) /\* OmniTAKMobile \*/ = \{[^}]*children = \((.*?)\);', new_content, re.DOTALL)

    if omnitak_group:
        children_content = omnitak_group.group(2)
        # Add new file references to children
        new_children_refs = []
        for filename in new_files:
            file_ref_id = file_refs[filename]
            new_children_refs.append(f'\t\t\t\t{file_ref_id} /* {filename} */,\n')

        # Insert before the closing of children array
        children_end = omnitak_group.end(2)
        new_content = new_content[:children_end] + ''.join(new_children_refs) + new_content[children_end:]

    # Find the Sources build phase and add build files
    sources_build_phase = re.search(r'([A-F0-9]{24}) /\* Sources \*/ = \{[^}]*files = \((.*?)\);', new_content, re.DOTALL)

    if sources_build_phase:
        files_content = sources_build_phase.group(2)
        # Add new build file references
        new_build_refs = []
        for filename in new_files:
            build_file_id = build_files[filename]
            new_build_refs.append(f'\t\t\t\t{build_file_id} /* {filename} in Sources */,\n')

        # Insert before the closing of files array
        files_end = sources_build_phase.end(2)
        new_content = new_content[:files_end] + ''.join(new_build_refs) + new_content[files_end:]

    # Write the updated project file
    with open(project_file, 'w') as f:
        f.write(new_content)

    print(f"✅ Added {len(new_files)} files to Xcode project")
    for filename in new_files:
        print(f"   - {filename}")

    return True

if __name__ == "__main__":
    print("🔧 Adding new Swift files to OmniTAKMobile Xcode project...")
    print()

    # Backup first
    backup_file = backup_project()

    # Add files
    success = add_files_to_project()

    if success:
        print()
        print("✅ SUCCESS! Files added to Xcode project")
        print(f"📝 Backup saved at: {backup_file}")
        print()
        print("Next steps:")
        print("1. Build the project in Xcode (⌘B)")
        print("2. If there are any issues, restore from backup")
    else:
        print()
        print("❌ Failed to add files")
        print(f"You can restore from backup: {backup_file}")
