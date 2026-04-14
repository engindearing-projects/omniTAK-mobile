#!/usr/bin/env python3
"""
Add MapLibre files to OmniTAKMobile Xcode project.
Specifically adds MapLibre3DView.swift, MapLibreService.swift, MapLibre3DSettingsView.swift
to a new MapLibre group under Features/Map.
"""

import uuid
import shutil

def generate_uuid():
    """Generate a 24-character uppercase hex UUID for Xcode."""
    return uuid.uuid4().hex[:24].upper()

def main():
    pbxproj_path = "./OmniTAKMobile.xcodeproj/project.pbxproj"

    # Create backup
    backup_path = pbxproj_path + ".maplibre_backup"
    shutil.copy2(pbxproj_path, backup_path)
    print(f"Backup created: {backup_path}")

    with open(pbxproj_path, 'r') as f:
        content = f.read()

    # Check if MapLibre files already added
    if 'MapLibre3DView.swift' in content:
        print("MapLibre files already appear to be in the project.")
        return

    # Generate UUIDs for new entries
    group_uuid = generate_uuid()
    file_ref_3dview = generate_uuid()
    file_ref_service = generate_uuid()
    file_ref_settings = generate_uuid()
    build_file_3dview = generate_uuid()
    build_file_service = generate_uuid()
    build_file_settings = generate_uuid()

    print(f"MapLibre group UUID: {group_uuid}")
    print(f"MapLibre3DView.swift ref: {file_ref_3dview}")
    print(f"MapLibreService.swift ref: {file_ref_service}")
    print(f"MapLibre3DSettingsView.swift ref: {file_ref_settings}")

    # 1. Add PBXBuildFile entries
    # Find the end of PBXBuildFile section and insert before it
    build_file_entries = f'''		{build_file_3dview} /* MapLibre3DView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_3dview} /* MapLibre3DView.swift */; }};
		{build_file_service} /* MapLibreService.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_service} /* MapLibreService.swift */; }};
		{build_file_settings} /* MapLibre3DSettingsView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_settings} /* MapLibre3DSettingsView.swift */; }};
'''

    content = content.replace(
        '/* End PBXBuildFile section */',
        build_file_entries + '/* End PBXBuildFile section */'
    )

    # 2. Add PBXFileReference entries
    # Find the end of PBXFileReference section and insert before it
    file_ref_entries = f'''		{file_ref_3dview} /* MapLibre3DView.swift */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = MapLibre3DView.swift; path = OmniTAKMobile/Features/Map/MapLibre/MapLibre3DView.swift; sourceTree = "<group>"; }};
		{file_ref_service} /* MapLibreService.swift */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = MapLibreService.swift; path = OmniTAKMobile/Features/Map/MapLibre/MapLibreService.swift; sourceTree = "<group>"; }};
		{file_ref_settings} /* MapLibre3DSettingsView.swift */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = MapLibre3DSettingsView.swift; path = OmniTAKMobile/Features/Map/MapLibre/MapLibre3DSettingsView.swift; sourceTree = "<group>"; }};
'''

    content = content.replace(
        '/* End PBXFileReference section */',
        file_ref_entries + '/* End PBXFileReference section */'
    )

    # 3. Add MapLibre group to PBXGroup section
    # Find end of PBXGroup section and insert before it
    group_entry = f'''		{group_uuid} /* MapLibre */ = {{
			isa = PBXGroup;
			children = (
				{file_ref_3dview} /* MapLibre3DView.swift */,
				{file_ref_service} /* MapLibreService.swift */,
				{file_ref_settings} /* MapLibre3DSettingsView.swift */,
			);
			name = MapLibre;
			sourceTree = "<group>";
		}};
'''

    content = content.replace(
        '/* End PBXGroup section */',
        group_entry + '/* End PBXGroup section */'
    )

    # 4. Add MapLibre group to Map's children
    # The Map group UUID is 41C532555828A88089BC2506
    # Insert MapLibre group reference in the children list
    map_group_children_start = '41C532555828A88089BC2506 /* Map */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = ('
    map_group_children_new = map_group_children_start + f'\n\t\t\t\t{group_uuid} /* MapLibre */,'

    content = content.replace(map_group_children_start, map_group_children_new)

    # 5. Add files to Sources build phase
    # Find the Sources build phase for OmniTAKMobile (UUID: 1111111111111111000000C1)
    # Look for the files = ( line after this UUID
    sources_files_entries = f'''				{build_file_3dview} /* MapLibre3DView.swift in Sources */,
				{build_file_service} /* MapLibreService.swift in Sources */,
				{build_file_settings} /* MapLibre3DSettingsView.swift in Sources */,
'''

    # Find the Sources build phase and add to it
    # The pattern is: isa = PBXSourcesBuildPhase; followed by files = (
    import re

    # Find Sources build phase with ID 1111111111111111000000C1
    sources_pattern = r'(1111111111111111000000C1 /\* Sources \*/ = \{[^}]*files = \()'
    match = re.search(sources_pattern, content, re.DOTALL)

    if match:
        content = content.replace(
            match.group(1),
            match.group(1) + '\n' + sources_files_entries
        )
        print("Added files to Sources build phase")
    else:
        print("Warning: Could not find Sources build phase")

    # Write the modified content
    with open(pbxproj_path, 'w') as f:
        f.write(content)

    print("\nSuccessfully added MapLibre files to project!")
    print("Files added:")
    print("  - MapLibre3DView.swift")
    print("  - MapLibreService.swift")
    print("  - MapLibre3DSettingsView.swift")

if __name__ == '__main__':
    main()
