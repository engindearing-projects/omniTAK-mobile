#!/usr/bin/env python3
"""
Add MapLibre Swift files to the Xcode project.
"""

import re
import uuid


def generate_uuid():
    """Generate a 24-character uppercase hex UUID for Xcode."""
    return uuid.uuid4().hex[:24].upper()


def main():
    pbxproj_path = "./OmniTAKMobile.xcodeproj/project.pbxproj"

    with open(pbxproj_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Generate UUIDs for files
    files = [
        ("MapLibre3DView.swift", "OmniTAKMobile/Features/Map/MapLibre/MapLibre3DView.swift"),
        ("MapLibreService.swift", "OmniTAKMobile/Features/Map/MapLibre/MapLibreService.swift"),
        ("MapLibre3DSettingsView.swift", "OmniTAKMobile/Features/Map/MapLibre/MapLibre3DSettingsView.swift"),
    ]

    file_refs = {}
    build_refs = {}

    for name, path in files:
        file_refs[name] = generate_uuid()
        build_refs[name] = generate_uuid()

    # Create MapLibre group
    group_uuid = generate_uuid()

    # 1. Add PBXFileReference entries
    file_ref_entries = []
    for name, path in files:
        uuid_ref = file_refs[name]
        entry = f'\t\t{uuid_ref} /* {name} */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = {name}; path = {path}; sourceTree = "<group>"; }};'
        file_ref_entries.append(entry)

    # Find end of PBXFileReference section and insert before it
    file_ref_section_end = "/* End PBXFileReference section */"
    insert_text = "\n".join(file_ref_entries) + "\n"
    content = content.replace(file_ref_section_end, insert_text + file_ref_section_end)

    # 2. Add PBXBuildFile entries
    build_file_entries = []
    for name, path in files:
        build_uuid = build_refs[name]
        file_uuid = file_refs[name]
        entry = f'\t\t{build_uuid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {name} */; }};'
        build_file_entries.append(entry)

    build_file_section_end = "/* End PBXBuildFile section */"
    insert_text = "\n".join(build_file_entries) + "\n"
    content = content.replace(build_file_section_end, insert_text + build_file_section_end)

    # 3. Add build file references to Sources build phase
    # Find the Sources build phase and add the files
    sources_pattern = r'(A11111111111111111111111000000C1 /\* Sources \*/ = \{[^}]*files = \([^)]*)'

    new_files = ",\n".join([f'\t\t\t\t{build_refs[name]} /* {name} in Sources */' for name, _ in files])

    def add_to_sources(match):
        return match.group(1) + ",\n" + new_files

    content = re.sub(sources_pattern, add_to_sources, content, count=1, flags=re.DOTALL)

    # 4. Create MapLibre group and add to Map group
    maplibre_group = f'''\t\t{group_uuid} /* MapLibre */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{file_refs["MapLibre3DView.swift"]} /* MapLibre3DView.swift */,
\t\t\t\t{file_refs["MapLibreService.swift"]} /* MapLibreService.swift */,
\t\t\t\t{file_refs["MapLibre3DSettingsView.swift"]} /* MapLibre3DSettingsView.swift */,
\t\t\t);
\t\t\tname = MapLibre;
\t\t\tpath = MapLibre;
\t\t\tsourceTree = "<group>";
\t\t}};
'''

    # Find end of PBXGroup section and insert the new group before it
    group_section_end = "/* End PBXGroup section */"
    content = content.replace(group_section_end, maplibre_group + group_section_end)

    # Find the Map group and add MapLibre as a child
    # Look for the Map folder group (the one with Controllers, Views, etc.)
    map_group_pattern = r'(41C532555828A88089BC2506 /\* Map \*/ = \{[^}]*children = \([^)]*)'

    def add_maplibre_to_map(match):
        return match.group(1) + f",\n\t\t\t\t{group_uuid} /* MapLibre */"

    content = re.sub(map_group_pattern, add_maplibre_to_map, content, count=1, flags=re.DOTALL)

    # Write the updated content
    with open(pbxproj_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print("Successfully added MapLibre Swift files to the Xcode project!")
    print(f"  - MapLibre3DView.swift ({file_refs['MapLibre3DView.swift']})")
    print(f"  - MapLibreService.swift ({file_refs['MapLibreService.swift']})")
    print(f"  - MapLibre3DSettingsView.swift ({file_refs['MapLibre3DSettingsView.swift']})")
    print(f"  - MapLibre group ({group_uuid})")


if __name__ == '__main__':
    main()
