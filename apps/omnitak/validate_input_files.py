#!/usr/bin/env python3
"""
Input File Validator

This script validates that project_analysis.json and group_structure.json
are properly formatted and contain the required data before running the rebuilder.
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Any


def validate_analysis_json(file_path: Path) -> Tuple[bool, List[str]]:
    """
    Validate project_analysis.json file.

    Returns:
        Tuple of (is_valid, list of errors/warnings)
    """
    errors = []
    warnings = []

    if not file_path.exists():
        errors.append(f"File not found: {file_path}")
        return False, errors

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        errors.append(f"Invalid JSON: {e}")
        return False, errors
    except Exception as e:
        errors.append(f"Error reading file: {e}")
        return False, errors

    # Check required top-level keys
    required_keys = [
        'file_references',
        'build_files',
        'groups',
        'native_targets',
        'sources_build_phase',
        'build_configurations',
        'configuration_lists',
        'project_object'
    ]

    for key in required_keys:
        if key not in data:
            errors.append(f"Missing required key: {key}")
        elif not isinstance(data[key], dict):
            errors.append(f"Key '{key}' must be a dictionary")
        elif len(data[key]) == 0:
            warnings.append(f"Key '{key}' is empty")

    # Validate file_references structure
    if 'file_references' in data:
        for ref_id, ref_data in data['file_references'].items():
            if 'isa' not in ref_data:
                errors.append(f"File reference {ref_id} missing 'isa'")
            if 'path' not in ref_data:
                warnings.append(f"File reference {ref_id} missing 'path'")

    # Validate build_files structure
    if 'build_files' in data:
        for build_id, build_data in data['build_files'].items():
            if 'isa' not in build_data:
                errors.append(f"Build file {build_id} missing 'isa'")
            if 'fileRef' not in build_data:
                errors.append(f"Build file {build_id} missing 'fileRef'")

    # Validate build configurations
    if 'build_configurations' in data:
        for config_id, config_data in data['build_configurations'].items():
            if 'buildSettings' not in config_data:
                errors.append(f"Config {config_id} missing 'buildSettings'")
            else:
                settings = config_data['buildSettings']
                # Check for critical settings
                if 'PRODUCT_BUNDLE_IDENTIFIER' not in settings:
                    warnings.append(f"Config {config_id} missing PRODUCT_BUNDLE_IDENTIFIER")
                if 'DEVELOPMENT_TEAM' not in settings:
                    warnings.append(f"Config {config_id} missing DEVELOPMENT_TEAM")

    is_valid = len(errors) == 0
    return is_valid, errors + warnings


def validate_structure_json(file_path: Path) -> Tuple[bool, List[str]]:
    """
    Validate group_structure.json file.

    Returns:
        Tuple of (is_valid, list of errors/warnings)
    """
    errors = []
    warnings = []

    if not file_path.exists():
        errors.append(f"File not found: {file_path}")
        return False, errors

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        errors.append(f"Invalid JSON: {e}")
        return False, errors
    except Exception as e:
        errors.append(f"Error reading file: {e}")
        return False, errors

    # Check for root key
    if 'root' not in data:
        errors.append("Missing required key: root")
        return False, errors

    root = data['root']

    # Validate root structure
    if 'name' not in root:
        errors.append("Root missing 'name'")

    if 'sourceTree' not in root:
        warnings.append("Root missing 'sourceTree' (will default to <group>)")

    # Recursively validate group structure
    def validate_group(group: Dict[str, Any], path: str = "root") -> None:
        if not isinstance(group, dict):
            errors.append(f"{path}: Group must be a dictionary")
            return

        if 'name' not in group:
            warnings.append(f"{path}: Missing 'name'")

        if 'children' in group:
            if not isinstance(group['children'], list):
                errors.append(f"{path}: 'children' must be a list")
            else:
                for i, child in enumerate(group['children']):
                    child_path = f"{path}/children[{i}]"
                    validate_group(child, child_path)

        if 'files' in group:
            if not isinstance(group['files'], list):
                errors.append(f"{path}: 'files' must be a list")
            else:
                for file_path in group['files']:
                    if not isinstance(file_path, str):
                        errors.append(f"{path}: File path must be a string: {file_path}")

    validate_group(root)

    # Count total files
    def count_files(group: Dict[str, Any]) -> int:
        count = len(group.get('files', []))
        for child in group.get('children', []):
            count += count_files(child)
        return count

    total_files = count_files(root)
    if total_files == 0:
        warnings.append("No files defined in structure (this may be intentional)")

    is_valid = len(errors) == 0
    return is_valid, errors + warnings


def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description='Validate input files for Xcode project rebuilder'
    )
    parser.add_argument(
        '--analysis',
        default='project_analysis.json',
        help='Path to project analysis JSON file (default: project_analysis.json)'
    )
    parser.add_argument(
        '--structure',
        default='group_structure.json',
        help='Path to group structure JSON file (default: group_structure.json)'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Show detailed output'
    )

    args = parser.parse_args()

    analysis_path = Path(args.analysis)
    structure_path = Path(args.structure)

    print("="*60)
    print("Input File Validator")
    print("="*60)
    print()

    # Validate analysis file
    print(f"Validating: {analysis_path}")
    analysis_valid, analysis_messages = validate_analysis_json(analysis_path)

    if analysis_valid:
        print("  ✅ Valid")
    else:
        print("  ❌ Invalid")

    if analysis_messages:
        for msg in analysis_messages:
            if "Error" in msg or "Missing required" in msg:
                print(f"  ❌ {msg}")
            else:
                print(f"  ⚠️  {msg}")

    print()

    # Validate structure file
    print(f"Validating: {structure_path}")
    structure_valid, structure_messages = validate_structure_json(structure_path)

    if structure_valid:
        print("  ✅ Valid")
    else:
        print("  ❌ Invalid")

    if structure_messages:
        for msg in structure_messages:
            if "Error" in msg or "Missing required" in msg:
                print(f"  ❌ {msg}")
            else:
                print(f"  ⚠️  {msg}")

    print()
    print("="*60)

    # Summary
    if analysis_valid and structure_valid:
        print("✅ All input files are valid!")
        print()
        print("You can now run the rebuilder:")
        print("  python3 rebuild_project.py OmniTAKMobile.xcodeproj")
        return 0
    else:
        print("❌ Some input files are invalid.")
        print()
        print("Please fix the errors above before running the rebuilder.")
        return 1


if __name__ == '__main__':
    sys.exit(main())
