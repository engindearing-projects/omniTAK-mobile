#!/usr/bin/env python3
"""
Xcode SPM Package Manager
Adds Swift Package Manager dependencies to Xcode projects programmatically.

Usage:
    python3 xcode_spm_manager.py add <package_url> [--version <version>] [--branch <branch>]
    python3 xcode_spm_manager.py list
    python3 xcode_spm_manager.py remove <package_name>

Examples:
    python3 xcode_spm_manager.py add https://github.com/maplibre/maplibre-gl-native-distribution --version 6.4.0
    python3 xcode_spm_manager.py list
"""

import os
import sys
import re
import uuid
import json
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
    backup_path = path + ".spm_backup"
    # Create backup
    with open(path, 'r', encoding='utf-8') as f:
        original = f.read()
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(original)
    print(f"Backup created: {backup_path}")

    # Write new content
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)


def get_package_name_from_url(url):
    """Extract package name from URL."""
    # Remove .git suffix if present
    if url.endswith('.git'):
        url = url[:-4]
    # Get the last path component
    return url.split('/')[-1]


def find_main_target(content):
    """Find the main app target UUID and name."""
    # Look for the main target (not test targets)
    pattern = r'(\w{24}) /\* (\w+) \*/ = \{[^}]*isa = PBXNativeTarget;[^}]*productType = "com\.apple\.product-type\.application";'
    match = re.search(pattern, content, re.DOTALL)
    if match:
        return match.group(1), match.group(2)

    # Fallback: look for any native target
    pattern = r'(\w{24}) /\* (\w+) \*/ = \{[^}]*isa = PBXNativeTarget;'
    match = re.search(pattern, content, re.DOTALL)
    if match:
        return match.group(1), match.group(2)

    return None, None


def find_root_object(content):
    """Find the root project object UUID."""
    match = re.search(r'rootObject = (\w{24})', content)
    return match.group(1) if match else None


def list_packages(content):
    """List existing SPM packages."""
    packages = []

    # Find XCRemoteSwiftPackageReference entries
    pattern = r'/\* XCRemoteSwiftPackageReference "([^"]+)" \*/ = \{[^}]*repositoryURL = "([^"]+)";[^}]*requirement = \{([^}]+)\}'
    for match in re.finditer(pattern, content, re.DOTALL):
        name = match.group(1)
        url = match.group(2)
        requirement = match.group(3).strip()
        packages.append({
            'name': name,
            'url': url,
            'requirement': requirement
        })

    return packages


def add_package(content, url, version=None, branch=None, exact=False, product_name=None):
    """Add an SPM package to the project."""
    package_name = get_package_name_from_url(url)
    # Use product_name if provided, otherwise use package_name
    actual_product_name = product_name if product_name else package_name

    # Check if package already exists
    existing = list_packages(content)
    for pkg in existing:
        if pkg['url'] == url or pkg['name'] == package_name:
            print(f"Package '{package_name}' already exists in project.")
            return content

    # Generate UUIDs
    package_ref_uuid = generate_uuid()
    package_product_uuid = generate_uuid()
    package_dep_uuid = generate_uuid()

    # Determine requirement
    if branch:
        requirement = f'''
				branch = {branch};
				kind = branch;'''
    elif exact and version:
        requirement = f'''
				kind = exactVersion;
				version = {version};'''
    elif version:
        requirement = f'''
				kind = upToNextMajorVersion;
				minimumVersion = {version};'''
    else:
        requirement = '''
				kind = upToNextMajorVersion;
				minimumVersion = 1.0.0;'''

    # Find insertion points
    root_uuid = find_root_object(content)
    target_uuid, target_name = find_main_target(content)

    if not root_uuid:
        print("Error: Could not find root project object")
        return content

    if not target_uuid:
        print("Error: Could not find main target")
        return content

    print(f"Adding package: {package_name}")
    print(f"  URL: {url}")
    print(f"  Target: {target_name} ({target_uuid})")

    # 1. Add XCRemoteSwiftPackageReference to PBXProject packageReferences
    # Find or create packageReferences array in the root project
    project_pattern = rf'({root_uuid} /\* Project object \*/ = \{{[^}}]*)'
    project_match = re.search(project_pattern, content, re.DOTALL)

    # Check if packageReferences exists anywhere in the project
    if 'packageReferences = (' in content:
        # Add to existing array
        content = re.sub(
            r'(packageReferences = \(\n)',
            f'\\1\t\t\t\t{package_ref_uuid} /* XCRemoteSwiftPackageReference "{package_name}" */,\n',
            content,
            count=1
        )
    else:
        # Add packageReferences array to PBXProject section
        # Insert after projectRoot = ""; line which is consistently right before targets
        content = re.sub(
            r'(projectRoot = "";)\n(\t+targets = \()',
            f'\\1\n\t\t\tpackageReferences = (\n\t\t\t\t{package_ref_uuid} /* XCRemoteSwiftPackageReference "{package_name}" */,\n\t\t\t);\n\\2',
            content,
            count=1
        )

    # 2. Add XCRemoteSwiftPackageReference section entry
    remote_package_entry = f'''
/* Begin XCRemoteSwiftPackageReference section */
		{package_ref_uuid} /* XCRemoteSwiftPackageReference "{package_name}" */ = {{
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "{url}";
			requirement = {{{requirement}
			}};
		}};
/* End XCRemoteSwiftPackageReference section */
'''

    # Check if section exists
    if '/* Begin XCRemoteSwiftPackageReference section */' in content:
        # Add to existing section
        content = re.sub(
            r'(/\* End XCRemoteSwiftPackageReference section \*/)',
            f'''\t\t{package_ref_uuid} /* XCRemoteSwiftPackageReference "{package_name}" */ = {{
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "{url}";
			requirement = {{{requirement}
			}};
		}};
\\1''',
            content
        )
    else:
        # Add new section before "	};\n	rootObject"
        content = re.sub(
            r'(\t\};[\s\n]+\trootObject)',
            f'/* Begin XCRemoteSwiftPackageReference section */\n\t\t{package_ref_uuid} /* XCRemoteSwiftPackageReference "{package_name}" */ = {{\n\t\t\tisa = XCRemoteSwiftPackageReference;\n\t\t\trepositoryURL = "{url}";\n\t\t\trequirement = {{{requirement}\n\t\t\t}};\n\t\t}};\n/* End XCRemoteSwiftPackageReference section */\n\\1',
            content
        )

    # 3. Add XCSwiftPackageProductDependency
    product_entry = f'''
/* Begin XCSwiftPackageProductDependency section */
		{package_product_uuid} /* {actual_product_name} */ = {{
			isa = XCSwiftPackageProductDependency;
			package = {package_ref_uuid} /* XCRemoteSwiftPackageReference "{package_name}" */;
			productName = {actual_product_name};
		}};
/* End XCSwiftPackageProductDependency section */
'''

    if '/* Begin XCSwiftPackageProductDependency section */' in content:
        content = re.sub(
            r'(/\* End XCSwiftPackageProductDependency section \*/)',
            f'''\t\t{package_product_uuid} /* {actual_product_name} */ = {{
			isa = XCSwiftPackageProductDependency;
			package = {package_ref_uuid} /* XCRemoteSwiftPackageReference "{package_name}" */;
			productName = {actual_product_name};
		}};
\\1''',
            content
        )
    else:
        # Add new section before "	};\n	rootObject"
        content = re.sub(
            r'(\t\};[\s\n]+\trootObject)',
            f'/* Begin XCSwiftPackageProductDependency section */\n\t\t{package_product_uuid} /* {actual_product_name} */ = {{\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = {package_ref_uuid} /* XCRemoteSwiftPackageReference "{package_name}" */;\n\t\t\tproductName = {actual_product_name};\n\t\t}};\n/* End XCSwiftPackageProductDependency section */\n\\1',
            content
        )

    # 4. Add packageProductDependencies to target
    target_pattern = rf'({target_uuid} /\* {target_name} \*/ = \{{[^}}]*buildPhases = \([^)]+\);)'

    if 'packageProductDependencies = (' in content:
        # Check if this target already has packageProductDependencies
        target_deps_pattern = rf'({target_uuid} /\* {target_name} \*/ = \{{[^}}]*packageProductDependencies = \([^)]*)'
        if re.search(target_deps_pattern, content, re.DOTALL):
            content = re.sub(
                target_deps_pattern,
                f'\\1\n\t\t\t\t{package_product_uuid} /* {actual_product_name} */,',
                content,
                count=1
            )
        else:
            # Add new packageProductDependencies to target
            content = re.sub(
                target_pattern,
                f'\\1\n\t\t\tpackageProductDependencies = (\n\t\t\t\t{package_product_uuid} /* {actual_product_name} */,\n\t\t\t);',
                content,
                count=1
            )
    else:
        content = re.sub(
            target_pattern,
            f'\\1\n\t\t\tpackageProductDependencies = (\n\t\t\t\t{package_product_uuid} /* {actual_product_name} */,\n\t\t\t);',
            content,
            count=1
        )

    print(f"Successfully added package '{package_name}'")
    print("\nNext steps:")
    print("1. Open Xcode and let it resolve packages (File > Packages > Resolve Package Versions)")
    print("2. Or run: xcodebuild -resolvePackageDependencies")

    return content


def remove_package(content, package_name):
    """Remove an SPM package from the project."""
    # Find the package UUID
    pattern = rf'(\w{{24}}) /\* XCRemoteSwiftPackageReference "{re.escape(package_name)}" \*/'
    match = re.search(pattern, content)

    if not match:
        print(f"Package '{package_name}' not found in project.")
        return content

    package_uuid = match.group(1)
    print(f"Removing package: {package_name} ({package_uuid})")

    # Remove from packageReferences array
    content = re.sub(
        rf'\s*{package_uuid} /\* XCRemoteSwiftPackageReference "{re.escape(package_name)}" \*/,?',
        '',
        content
    )

    # Remove XCRemoteSwiftPackageReference entry
    content = re.sub(
        rf'\s*{package_uuid} /\* XCRemoteSwiftPackageReference "{re.escape(package_name)}" \*/ = \{{[^}}]+\}};',
        '',
        content
    )

    # Find and remove XCSwiftPackageProductDependency
    product_pattern = rf'(\w{{24}}) /\* {re.escape(package_name)} \*/ = \{{[^}}]*package = {package_uuid}'
    product_match = re.search(product_pattern, content)

    if product_match:
        product_uuid = product_match.group(1)

        # Remove from packageProductDependencies array
        content = re.sub(
            rf'\s*{product_uuid} /\* {re.escape(package_name)} \*/,?',
            '',
            content
        )

        # Remove XCSwiftPackageProductDependency entry
        content = re.sub(
            rf'\s*{product_uuid} /\* {re.escape(package_name)} \*/ = \{{[^}}]+\}};',
            '',
            content
        )

    print(f"Successfully removed package '{package_name}'")
    return content


def main():
    parser = argparse.ArgumentParser(description='Xcode SPM Package Manager')
    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # Add command
    add_parser = subparsers.add_parser('add', help='Add a package')
    add_parser.add_argument('url', help='Package repository URL')
    add_parser.add_argument('--version', '-v', help='Minimum version (e.g., 6.4.0)')
    add_parser.add_argument('--branch', '-b', help='Branch name')
    add_parser.add_argument('--exact', '-e', action='store_true', help='Use exact version')
    add_parser.add_argument('--product', help='Product name if different from repo name (e.g., MapLibre)')
    add_parser.add_argument('--project', '-p', help='Path to .xcodeproj directory')

    # List command
    list_parser = subparsers.add_parser('list', help='List packages')
    list_parser.add_argument('--project', '-p', help='Path to .xcodeproj directory')

    # Remove command
    remove_parser = subparsers.add_parser('remove', help='Remove a package')
    remove_parser.add_argument('name', help='Package name')
    remove_parser.add_argument('--project', '-p', help='Path to .xcodeproj directory')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    # Find project file
    start_path = args.project if hasattr(args, 'project') and args.project else '.'
    pbxproj_path = find_pbxproj(start_path)

    if not pbxproj_path:
        print("Error: Could not find .xcodeproj/project.pbxproj")
        print("Make sure you're in the project directory or specify --project path")
        sys.exit(1)

    print(f"Using project: {pbxproj_path}")
    content = read_pbxproj(pbxproj_path)

    if args.command == 'list':
        packages = list_packages(content)
        if packages:
            print("\nInstalled SPM Packages:")
            print("-" * 60)
            for pkg in packages:
                print(f"  {pkg['name']}")
                print(f"    URL: {pkg['url']}")
                print(f"    {pkg['requirement'].strip()}")
                print()
        else:
            print("No SPM packages found in project.")

    elif args.command == 'add':
        new_content = add_package(
            content,
            args.url,
            version=args.version,
            branch=args.branch,
            exact=args.exact,
            product_name=args.product
        )
        if new_content != content:
            write_pbxproj(pbxproj_path, new_content)

    elif args.command == 'remove':
        new_content = remove_package(content, args.name)
        if new_content != content:
            write_pbxproj(pbxproj_path, new_content)


if __name__ == '__main__':
    main()
