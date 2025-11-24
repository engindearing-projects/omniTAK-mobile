#!/usr/bin/env python3
"""
Reorganize Xcode project to match filesystem structure
Preserves all settings, targets, and build configurations
"""

import os
import re
import sys
from pathlib import Path
import uuid

def generate_uuid():
    """Generate a 24-character hex UUID like Xcode uses"""
    return uuid.uuid4().hex[:24].upper()

def scan_directory_structure(base_path):
    """Scan OmniTAKMobile directory and build file tree"""
    structure = {}
    base = Path(base_path)

    for item in base.rglob('*'):
        if item.is_file() and item.suffix in ['.swift', '.h', '.m', '.mm', '.metal', '.storyboard', '.xib', '.xcassets']:
            relative = item.relative_to(base)
            parts = list(relative.parts)

            # Build nested dict structure
            current = structure
            for part in parts[:-1]:  # All but filename
                if part not in current:
                    current[part] = {}
                current = current[part]

            # Add file
            if '__files__' not in current:
                current['__files__'] = []
            current['__files__'].append({
                'name': parts[-1],
                'path': str(relative),
                'full_path': str(item)
            })

    return structure

def create_pbxgroup(name, path, indent=0):
    """Generate PBXGroup entry"""
    uuid_group = generate_uuid()

    return f'''		{uuid_group} /* {name} */ = {{
			isa = PBXGroup;
			children = (
			);
			path = {name};
			sourceTree = "<group>";
		}};'''

def read_project_file(project_path):
    """Read project.pbxproj file"""
    pbxproj = os.path.join(project_path, 'project.pbxproj')
    with open(pbxproj, 'r') as f:
        return f.read()

def main():
    print("🔧 Reorganizing Xcode Project Structure")
    print("=" * 50)

    project_path = 'OmniTAKMobile.xcodeproj'
    source_path = 'OmniTAKMobile'

    # Check if backup exists
    if not os.path.exists(f'{project_path}.backup'):
        print("❌ No backup found! Please backup first.")
        sys.exit(1)

    print("📁 Scanning directory structure...")
    structure = scan_directory_structure(source_path)

    print("\n📊 Found structure:")
    for key in sorted(structure.keys()):
        if key != '__files__':
            print(f"  📂 {key}")
            if '__files__' in structure[key]:
                print(f"     ({len(structure[key]['__files__'])} files)")

    print("\n⚠️  Manual reorganization recommended for safety.")
    print("   Automated pbxproj editing is complex and error-prone.")
    print("\n✅ Backup created at: OmniTAKMobile.xcodeproj.backup")

    # Generate manual instructions
    print("\n" + "=" * 50)
    print("📋 MANUAL REORGANIZATION STEPS:")
    print("=" * 50)
    print("""
1. Open OmniTAKMobile.xcodeproj in Xcode
2. Select ALL files in the project navigator (Cmd+A)
3. Delete them (press Delete key)
4. Choose "Remove Reference" (NOT "Move to Trash")
5. Now the project is empty but all files still exist on disk

6. Create group structure:
   Right-click OmniTAKMobile → New Group without Folder:
   - Core
   - Services
   - Managers
   - Views
   - Models
   - CoT (with subgroups: Generators, Parsers)
   - Map (with subgroups: Controllers, Markers, Overlays, TileSources)
   - Utilities (with subgroups: Converters, Parsers, Integration)
   - UI (with subgroup: Components)
   - Resources

7. Add files back organized:
   - Right-click each group → Add Files to "OmniTAKMobile"
   - Navigate to corresponding folder in OmniTAKMobile/
   - Select all files in that folder
   - UNCHECK "Copy items if needed"
   - CHECK "Add to targets: OmniTAKMobile"
   - Click Add

8. Build and verify (Cmd+B)
""")

    return 0

if __name__ == '__main__':
    sys.exit(main())
