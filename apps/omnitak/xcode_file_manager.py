#!/usr/bin/env python3
"""
Xcode File Manager
Adds Swift files to Xcode projects programmatically.
"""

import os
import sys
import re
import uuid
import argparse
from pathlib import Path


def generate_uuid():
    """Generate a 24-character uppercase hex UUID for Xcode."""
    return uuid.uuid4().hex[:24].upper()


def find_pbxproj(start_path="."):
    """Find the project.pbxproj file."""
    for root, dirs, files in os.walk(start_path):
        for d in dirs:
            if d.endswith(".xcodeproj"):
                pbxproj = os.path.join(root, d, "project.pbxproj")
                if os.path.exists(pbxproj):
                    return pbxproj
    return None


def read_pbxproj(path):
    """Read the pbxproj file."""
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()


def write_pbxproj(path, content):
    """Write the pbxproj file with backup."""
    backup_path = path + ".file_backup"
    with open(path, 'r', encoding='utf-8') as f:
        original = f.read()
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(original)
    print(f"Backup created: {backup_path}")

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)


def find_group_uuid(content, group_name):
    """Find a group's UUID by name."""
    pattern = rf'(\w{{24}}) /\* {re.escape(group_name)} \*/ = \{{\s*isa = PBXGroup;'
    match = re.search(pattern, content)
    if match:
        return match.group(1)
    return None


def find_sources_build_phase(content):
    """Find the main Sources build phase UUID."""
    pattern = r'(\w{24}) /\* Sources \*/ = \{\s*isa = PBXSourcesBuildPhase;'
    matches = list(re.finditer(pattern, content))
    if matches:
        return matches[0].group(1)
    return None


def add_to_array(content, array_pattern, new_entry):
    """
    Add an entry to a pbxproj array.
    The array_pattern should match up to and including 'array_name = ('
    """
    def replacer(match):
        array_start = match.group(0)
        # Find the closing paren by counting depth
        pos = match.end()
        depth = 1
        while pos < len(content) and depth > 0:
            if content[pos] == '(':
                depth += 1
            elif content[pos] == ')':
                depth -= 1
            pos += 1

        # pos is now right after the closing ')'
        array_content = content[match.end():pos-1]

        # Check if array is empty or has content
        if array_content.strip():
            # Array has content, add with proper formatting
            # Find the last non-whitespace content
            lines = array_content.rstrip().rstrip(',')
            new_array_content = lines + ",\n" + new_entry + ","
        else:
            # Empty array
            new_array_content = "\n" + new_entry + ","

        return array_start + new_array_content + "\n\t\t\t)"

    return re.sub(array_pattern, replacer, content, count=1, flags=re.DOTALL)


def add_swift_files(content, files, parent_group_name, group_name=None):
    """Add Swift files to the project under a parent group."""

    # Find parent group
    parent_uuid = find_group_uuid(content, parent_group_name)
    if not parent_uuid:
        print(f"Error: Could not find group '{parent_group_name}'")
        return content

    print(f"Found parent group: {parent_group_name} ({parent_uuid})")

    # Find Sources build phase
    sources_uuid = find_sources_build_phase(content)
    if not sources_uuid:
        print("Error: Could not find Sources build phase")
        return content

    print(f"Found Sources build phase: {sources_uuid}")

    # Generate UUIDs for files
    file_data = []
    for file_path in files:
        file_name = os.path.basename(file_path)
        file_ref_uuid = generate_uuid()
        build_file_uuid = generate_uuid()
        file_data.append({
            'name': file_name,
            'path': file_path,
            'file_ref_uuid': file_ref_uuid,
            'build_file_uuid': build_file_uuid
        })

    # Create group if needed
    if group_name:
        group_uuid = generate_uuid()

        # Create the group entry
        group_children = "\n".join([f"\t\t\t\t{f['file_ref_uuid']} /* {f['name']} */," for f in file_data])
        group_entry = f"""\t\t{group_uuid} /* {group_name} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{group_children}
\t\t\t);
\t\t\tname = {group_name};
\t\t\tpath = {group_name};
\t\t\tsourceTree = "<group>";
\t\t}};
"""

        # Insert group before /* End PBXGroup section */
        content = content.replace(
            "/* End PBXGroup section */",
            group_entry + "/* End PBXGroup section */"
        )
        print(f"Created group: {group_name} ({group_uuid})")

        # Add group to parent's children
        parent_children_pattern = rf'{parent_uuid} /\* {re.escape(parent_group_name)} \*/ = \{{\s*isa = PBXGroup;\s*children = \('
        new_child_entry = f"\t\t\t\t{group_uuid} /* {group_name} */"
        content = add_to_array(content, parent_children_pattern, new_child_entry)
        print(f"Added {group_name} to {parent_group_name}'s children")
    else:
        # Add files directly to parent group
        parent_children_pattern = rf'{parent_uuid} /\* {re.escape(parent_group_name)} \*/ = \{{\s*isa = PBXGroup;\s*children = \('
        for f in file_data:
            new_child_entry = f"\t\t\t\t{f['file_ref_uuid']} /* {f['name']} */"
            content = add_to_array(content, parent_children_pattern, new_child_entry)

    # Add PBXFileReference entries
    file_ref_entries = []
    for f in file_data:
        entry = f"\t\t{f['file_ref_uuid']} /* {f['name']} */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = {f['name']}; path = {f['path']}; sourceTree = \"<group>\"; }};"
        file_ref_entries.append(entry)

    file_refs_text = "\n".join(file_ref_entries) + "\n"
    content = content.replace(
        "/* End PBXFileReference section */",
        file_refs_text + "/* End PBXFileReference section */"
    )
    print(f"Added {len(file_data)} file references")

    # Add PBXBuildFile entries
    build_file_entries = []
    for f in file_data:
        entry = f"\t\t{f['build_file_uuid']} /* {f['name']} in Sources */ = {{isa = PBXBuildFile; fileRef = {f['file_ref_uuid']} /* {f['name']} */; }};"
        build_file_entries.append(entry)

    build_files_text = "\n".join(build_file_entries) + "\n"
    content = content.replace(
        "/* End PBXBuildFile section */",
        build_files_text + "/* End PBXBuildFile section */"
    )
    print(f"Added {len(file_data)} build file entries")

    # Add to Sources build phase
    sources_files_pattern = rf'{sources_uuid} /\* Sources \*/ = \{{\s*isa = PBXSourcesBuildPhase;[^}}]*files = \('
    for f in file_data:
        new_source_entry = f"\t\t\t\t{f['build_file_uuid']} /* {f['name']} in Sources */"
        content = add_to_array(content, sources_files_pattern, new_source_entry)
    print(f"Added files to Sources build phase")

    return content


def list_groups(content):
    """List all groups in the project."""
    pattern = r'(\w{24}) /\* ([^*]+) \*/ = \{\s*isa = PBXGroup;[^}]*children = \(([^)]*)\);[^}]*(?:name = ([^;]+);)?'
    groups = []
    for match in re.finditer(pattern, content, re.DOTALL):
        uuid_val = match.group(1)
        comment_name = match.group(2).strip()
        children = match.group(3)
        name = match.group(4).strip() if match.group(4) else None

        child_count = len([c for c in children.split(',') if c.strip()])

        groups.append({
            'uuid': uuid_val,
            'comment': comment_name,
            'name': name,
            'child_count': child_count
        })
    return groups


def main():
    parser = argparse.ArgumentParser(description='Xcode File Manager')
    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # add-files command
    add_files_parser = subparsers.add_parser('add-files', help='Add Swift files to project')
    add_files_parser.add_argument('files', nargs='+', help='Swift file paths')
    add_files_parser.add_argument('--parent', required=True, help='Parent group name')
    add_files_parser.add_argument('--group', help='Create new group with this name')
    add_files_parser.add_argument('--project', '-p', help='Path to .xcodeproj directory')

    # list-groups command
    list_parser = subparsers.add_parser('list-groups', help='List all groups')
    list_parser.add_argument('--project', '-p', help='Path to .xcodeproj directory')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    start_path = args.project if hasattr(args, 'project') and args.project else '.'
    pbxproj_path = find_pbxproj(start_path)

    if not pbxproj_path:
        print("Error: Could not find .xcodeproj/project.pbxproj")
        sys.exit(1)

    print(f"Using project: {pbxproj_path}")
    content = read_pbxproj(pbxproj_path)

    if args.command == 'list-groups':
        groups = list_groups(content)
        print(f"\nFound {len(groups)} groups:")
        print("-" * 70)
        for g in sorted(groups, key=lambda x: x['comment']):
            display_name = g['name'] or g['comment']
            print(f"  {display_name} [{g['child_count']} children]")

    elif args.command == 'add-files':
        new_content = add_swift_files(
            content,
            args.files,
            parent_group_name=args.parent,
            group_name=args.group
        )
        if new_content != content:
            write_pbxproj(pbxproj_path, new_content)
            print("\nSuccess! Files added to project.")
        else:
            print("\nNo changes made.")


if __name__ == '__main__':
    main()
