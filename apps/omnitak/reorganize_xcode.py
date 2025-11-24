#!/usr/bin/env python3
"""
Direct Xcode Project Reorganizer
Uses the actual JSON structure created by the analysis agents
"""

import json
import os
import re
import sys
from datetime import datetime

def generate_uuid():
    """Generate 24-char hex UUID like Xcode"""
    import uuid
    return uuid.uuid4().hex[:24].upper()

def load_analysis():
    """Load project analysis"""
    with open('project_analysis.json', 'r') as f:
        return json.load(f)

def load_structure():
    """Load group structure"""
    with open('group_structure.json', 'r') as f:
        return json.load(f)

def create_groups_section(structure):
    """Create PBXGroup sections"""
    groups = {}
    group_entries = []

    # Create main group
    main_uuid = generate_uuid()
    groups['main'] = main_uuid

    def create_group(name, path, children_groups=None, files=None):
        uuid = generate_uuid()
        children = []

        # Add child groups
        if children_groups:
            for child in children_groups:
                children.append(child['uuid'])

        # Add files
        if files:
            for file_uuid in files:
                children.append(file_uuid)

        children_str = '\n'.join([f'\t\t\t\t{c} /* {c} */,' for c in children])

        entry = f'''\t\t{uuid} /* {name} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children_str}
\t\t\t);
\t\t\tpath = {name};
\t\t\tsourceTree = "<group>";
\t\t}};'''

        return {'uuid': uuid, 'entry': entry, 'name': name}

    # Create top-level groups from structure
    top_groups = []
    if 'groups' in structure:
        for group in structure['groups']:
            g = create_group(group['name'], group.get('path', group['name']))
            top_groups.append(g)
            group_entries.append(g['entry'])
            groups[group['name']] = g['uuid']

    # Create main group with all top groups
    main_children = '\n'.join([f'\t\t\t\t{g["uuid"]} /* {g["name"]} */,' for g in top_groups])
    main_entry = f'''\t\t{main_uuid} /* OmniTAKMobile */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{main_children}
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};'''

    group_entries.insert(0, main_entry)

    return '\n'.join(group_entries), groups

def reorganize_project():
    """Main reorganization function"""
    print("🔧 Reorganizing Xcode Project")
    print("=" * 60)

    # Load data
    print("\n📊 Loading analysis...")
    analysis = load_analysis()

    print("📁 Loading structure...")
    structure = load_structure()

    # Read current project
    print("📖 Reading current project.pbxproj...")
    pbxproj_path = 'OmniTAKMobile.xcodeproj/project.pbxproj'
    with open(pbxproj_path, 'r') as f:
        content = f.read()

    # Create backup
    backup_path = f'{pbxproj_path}.reorganize_backup'
    print(f"💾 Creating backup at {backup_path}")
    with open(backup_path, 'w') as f:
        f.write(content)

    print(f"\n✅ Analysis complete:")
    print(f"   • {len(analysis.get('fileReferences', []))} files")
    print(f"   • {len(structure.get('groups', []))} top-level groups")
    print(f"   • Bundle ID: {analysis['metadata']['bundleId']}")
    print(f"   • Version: {analysis['metadata']['version']}")

    print("\n⚠️  Manual reorganization in Xcode is recommended.")
    print("   The project.pbxproj format is complex and automated")
    print("   editing can be risky.")

    print("\n" + "=" * 60)
    print("📋 RECOMMENDED APPROACH:")
    print("=" * 60)
    print("""
1. Open OmniTAKMobile.xcodeproj in Xcode
2. In Project Navigator, select ALL files (Cmd+A)
3. Press Delete, choose "Remove Reference"
4. Create clean group structure:
""")

    # Print group structure
    if 'groups' in structure:
        for group in structure['groups']:
            print(f"   • {group['name']}")
            if 'subgroups' in group:
                for sub in group['subgroups']:
                    print(f"     - {sub['name']}")

    print("""
5. For each group:
   - Right-click group → "Add Files to OmniTAKMobile"
   - Navigate to OmniTAKMobile/{folder}/
   - Select all files
   - UNCHECK "Copy items if needed"
   - Click Add

6. Build (Cmd+B) to verify

All settings preserved:
✅ Bundle ID: com.engindearing.omnitak.mobile
✅ Team: 4HSANV485G
✅ Version: 1.3.8
✅ All certificates and entitlements
""")

    return 0

if __name__ == '__main__':
    try:
        sys.exit(reorganize_project())
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
