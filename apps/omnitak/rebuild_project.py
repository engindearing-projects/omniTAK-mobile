#!/usr/bin/env python3
"""
Xcode Project Rebuilder

This script reads analysis data and group structure JSON files to rebuild
an Xcode project.pbxproj file with proper organization while preserving
all build settings, configurations, and target memberships.

Requirements:
- project_analysis.json: Contains all file references, build files, and settings
- group_structure.json: Contains the desired group hierarchy

Preserves:
- Bundle ID: com.engindearing.omnitak.mobile
- Team: 4HSANV485G
- Version: 1.3.8
- All capabilities, entitlements, and signing settings
"""

import json
import os
import sys
import uuid
import hashlib
from pathlib import Path
from typing import Dict, List, Set, Tuple, Any, Optional
from collections import defaultdict
from datetime import datetime


class XcodeProjectRebuilder:
    """Rebuilds an Xcode project.pbxproj file with proper organization."""

    def __init__(self, project_path: str, analysis_path: str, structure_path: str):
        """
        Initialize the rebuilder.

        Args:
            project_path: Path to the .xcodeproj directory
            analysis_path: Path to project_analysis.json
            structure_path: Path to group_structure.json
        """
        self.project_path = Path(project_path)
        self.pbxproj_path = self.project_path / "project.pbxproj"
        self.analysis_path = Path(analysis_path)
        self.structure_path = Path(structure_path)

        # Data structures
        self.analysis: Dict[str, Any] = {}
        self.group_structure: Dict[str, Any] = {}
        self.file_references: Dict[str, Dict[str, Any]] = {}
        self.build_files: Dict[str, Dict[str, Any]] = {}
        self.groups: Dict[str, Dict[str, Any]] = {}
        self.existing_ids: Set[str] = set()

        # Mapping from file path to file reference ID
        self.path_to_fileref: Dict[str, str] = {}
        # Mapping from file reference ID to build file IDs
        self.fileref_to_buildfile: Dict[str, List[str]] = defaultdict(list)

        # Critical settings to preserve
        self.bundle_id = "com.engindearing.omnitak.mobile"
        self.team_id = "4HSANV485G"
        self.marketing_version = "1.3.8"
        self.current_project_version = "1.3.8"

    def generate_id(self, base_string: str = None) -> str:
        """
        Generate a unique 24-character hex ID for Xcode objects.

        Args:
            base_string: Optional string to seed the ID generation

        Returns:
            24-character hex ID
        """
        if base_string:
            # Use hash of base string for consistency
            hash_obj = hashlib.md5(base_string.encode())
            candidate = hash_obj.hexdigest()[:24].upper()
        else:
            # Generate random ID
            candidate = uuid.uuid4().hex[:24].upper()

        # Ensure uniqueness
        while candidate in self.existing_ids:
            candidate = uuid.uuid4().hex[:24].upper()

        self.existing_ids.add(candidate)
        return candidate

    def load_analysis(self) -> None:
        """Load the project analysis JSON file."""
        print(f"Loading analysis from: {self.analysis_path}")

        if not self.analysis_path.exists():
            raise FileNotFoundError(
                f"Analysis file not found: {self.analysis_path}\n"
                "Please run the analysis agent first to generate this file."
            )

        with open(self.analysis_path, 'r', encoding='utf-8') as f:
            self.analysis = json.load(f)

        print(f"  - Loaded {len(self.analysis.get('file_references', {}))} file references")
        print(f"  - Loaded {len(self.analysis.get('build_files', {}))} build files")
        print(f"  - Loaded {len(self.analysis.get('groups', {}))} groups")

    def load_group_structure(self) -> None:
        """Load the desired group structure JSON file."""
        print(f"Loading group structure from: {self.structure_path}")

        if not self.structure_path.exists():
            raise FileNotFoundError(
                f"Group structure file not found: {self.structure_path}\n"
                "Please run the structure planning agent first to generate this file."
            )

        with open(self.structure_path, 'r', encoding='utf-8') as f:
            self.group_structure = json.load(f)

        print(f"  - Loaded group structure with {len(self.group_structure.get('groups', {}))} top-level groups")

    def build_file_reference_map(self) -> None:
        """Build a map of file paths to file reference IDs from analysis."""
        print("Building file reference map...")

        file_refs = self.analysis.get('file_references', {})
        for ref_id, ref_data in file_refs.items():
            path = ref_data.get('path', '')
            if path:
                self.path_to_fileref[path] = ref_id
                self.file_references[ref_id] = ref_data
                self.existing_ids.add(ref_id)

        print(f"  - Mapped {len(self.path_to_fileref)} file paths to references")

    def build_fileref_buildfile_map(self) -> None:
        """Build a map of file reference IDs to build file IDs."""
        print("Building file reference to build file map...")

        build_files = self.analysis.get('build_files', {})
        for build_id, build_data in build_files.items():
            fileref_id = build_data.get('fileRef')
            if fileref_id:
                self.fileref_to_buildfile[fileref_id].append(build_id)
                self.build_files[build_id] = build_data
                self.existing_ids.add(build_id)

        print(f"  - Mapped {len(self.fileref_to_buildfile)} file references to build files")

    def create_groups_from_structure(self) -> Tuple[str, Dict[str, str]]:
        """
        Create PBXGroup entries from the group structure.

        Returns:
            Tuple of (root_group_id, path_to_group_id_map)
        """
        print("Creating groups from structure...")

        path_to_group: Dict[str, str] = {}

        def create_group(group_data: Dict[str, Any], parent_path: str = "") -> str:
            """Recursively create groups."""
            group_name = group_data.get('name', 'Unknown')
            group_path = f"{parent_path}/{group_name}" if parent_path else group_name

            # Generate ID for this group
            group_id = self.generate_id(f"group_{group_path}")
            path_to_group[group_path] = group_id

            # Create group entry
            children = []

            # Process child groups
            for child_group in group_data.get('children', []):
                if isinstance(child_group, dict) and 'name' in child_group:
                    child_id = create_group(child_group, group_path)
                    children.append(child_id)

            # Process files
            for file_path in group_data.get('files', []):
                # Find or create file reference
                if file_path in self.path_to_fileref:
                    fileref_id = self.path_to_fileref[file_path]
                    children.append(fileref_id)
                else:
                    # File not in analysis - create new reference
                    fileref_id = self.create_file_reference(file_path)
                    children.append(fileref_id)

            # Determine source tree
            source_tree = group_data.get('sourceTree', '<group>')

            # Determine path (for filesystem-based groups)
            path_value = group_data.get('path', '')

            self.groups[group_id] = {
                'isa': 'PBXGroup',
                'children': children,
                'name': group_name,
                'sourceTree': source_tree
            }

            if path_value:
                self.groups[group_id]['path'] = path_value

            return group_id

        # Create root group
        root_structure = self.group_structure.get('root', {})
        root_id = create_group(root_structure)

        print(f"  - Created {len(self.groups)} groups")
        return root_id, path_to_group

    def create_file_reference(self, file_path: str) -> str:
        """
        Create a new PBXFileReference entry.

        Args:
            file_path: Path to the file

        Returns:
            File reference ID
        """
        fileref_id = self.generate_id(f"fileref_{file_path}")

        # Determine file type
        ext = Path(file_path).suffix.lower()
        file_type_map = {
            '.swift': 'sourcecode.swift',
            '.h': 'sourcecode.c.h',
            '.m': 'sourcecode.c.objc',
            '.mm': 'sourcecode.cpp.objcpp',
            '.c': 'sourcecode.c.c',
            '.cpp': 'sourcecode.cpp.cpp',
            '.xcassets': 'folder.assetcatalog',
            '.storyboard': 'file.storyboard',
            '.xib': 'file.xib',
            '.plist': 'text.plist.xml',
            '.json': 'text.json',
            '.xcframework': 'wrapper.xcframework',
            '.framework': 'wrapper.framework',
            '.p12': 'file',
        }

        file_type = file_type_map.get(ext, 'text')

        self.file_references[fileref_id] = {
            'isa': 'PBXFileReference',
            'lastKnownFileType': file_type,
            'path': file_path,
            'sourceTree': '<group>'
        }

        self.path_to_fileref[file_path] = fileref_id
        return fileref_id

    def generate_pbxproj_content(self, root_group_id: str) -> str:
        """
        Generate the complete project.pbxproj file content.

        Args:
            root_group_id: ID of the root group

        Returns:
            Complete pbxproj file content as string
        """
        print("Generating project.pbxproj content...")

        lines = [
            "// !$*UTF8*$!",
            "{",
            "\tarchiveVersion = 1;",
            "\tclasses = {",
            "\t};",
            "\tobjectVersion = 56;",
            "\tobjects = {",
            ""
        ]

        # Generate PBXBuildFile section
        lines.append("/* Begin PBXBuildFile section */")
        for build_id in sorted(self.build_files.keys()):
            build_data = self.build_files[build_id]
            fileref_id = build_data.get('fileRef')

            # Get file reference for comment
            comment = ""
            if fileref_id in self.file_references:
                file_path = self.file_references[fileref_id].get('path', '')
                comment = f" /* {file_path} in Sources */"

            lines.append(f"\t\t{build_id}{comment} = {{isa = PBXBuildFile; fileRef = {fileref_id}{comment.replace(' in Sources', '')}; }};")

        lines.append("/* End PBXBuildFile section */")
        lines.append("")

        # Generate PBXFileReference section
        lines.append("/* Begin PBXFileReference section */")
        for ref_id in sorted(self.file_references.keys()):
            ref_data = self.file_references[ref_id]
            file_path = ref_data.get('path', '')
            file_type = ref_data.get('lastKnownFileType', 'text')
            source_tree = ref_data.get('sourceTree', '<group>')

            comment = f" /* {Path(file_path).name} */" if file_path else ""

            line = f"\t\t{ref_id}{comment} = {{isa = PBXFileReference; lastKnownFileType = {file_type}; path = {file_path}; sourceTree = {source_tree}; }};"
            lines.append(line)

        lines.append("/* End PBXFileReference section */")
        lines.append("")

        # Generate PBXFrameworksBuildPhase section (from analysis)
        frameworks_phase = self.analysis.get('frameworks_build_phase', {})
        if frameworks_phase:
            lines.append("/* Begin PBXFrameworksBuildPhase section */")
            for phase_id, phase_data in frameworks_phase.items():
                lines.append(f"\t\t{phase_id} /* Frameworks */ = {{")
                lines.append(f"\t\t\tisa = PBXFrameworksBuildPhase;")
                lines.append(f"\t\t\tbuildActionMask = {phase_data.get('buildActionMask', 2147483647)};")
                lines.append(f"\t\t\tfiles = (")
                for file_id in phase_data.get('files', []):
                    lines.append(f"\t\t\t\t{file_id},")
                lines.append(f"\t\t\t);")
                lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = {phase_data.get('runOnlyForDeploymentPostprocessing', 0)};")
                lines.append(f"\t\t}};")
            lines.append("/* End PBXFrameworksBuildPhase section */")
            lines.append("")

        # Generate PBXGroup section
        lines.append("/* Begin PBXGroup section */")
        for group_id in sorted(self.groups.keys()):
            group_data = self.groups[group_id]
            group_name = group_data.get('name', '')

            comment = f" /* {group_name} */" if group_name else ""

            lines.append(f"\t\t{group_id}{comment} = {{")
            lines.append(f"\t\t\tisa = PBXGroup;")
            lines.append(f"\t\t\tchildren = (")
            for child_id in group_data.get('children', []):
                # Add comment for child
                child_comment = ""
                if child_id in self.file_references:
                    file_path = self.file_references[child_id].get('path', '')
                    child_comment = f" /* {Path(file_path).name} */" if file_path else ""
                elif child_id in self.groups:
                    child_name = self.groups[child_id].get('name', '')
                    child_comment = f" /* {child_name} */" if child_name else ""

                lines.append(f"\t\t\t\t{child_id},{child_comment}")
            lines.append(f"\t\t\t);")

            if group_name:
                lines.append(f'\t\t\tname = "{group_name}";')

            path = group_data.get('path', '')
            if path:
                lines.append(f'\t\t\tpath = "{path}";')

            lines.append(f'\t\t\tsourceTree = "{group_data.get("sourceTree", "<group>")!s}";')
            lines.append(f"\t\t}};")

        lines.append("/* End PBXGroup section */")
        lines.append("")

        # Generate PBXNativeTarget section (from analysis)
        native_targets = self.analysis.get('native_targets', {})
        if native_targets:
            lines.append("/* Begin PBXNativeTarget section */")
            for target_id, target_data in native_targets.items():
                target_name = target_data.get('name', 'OmniTAKMobile')
                lines.append(f"\t\t{target_id} /* {target_name} */ = {{")
                lines.append(f"\t\t\tisa = PBXNativeTarget;")
                lines.append(f"\t\t\tbuildConfigurationList = {target_data.get('buildConfigurationList')};")
                lines.append(f"\t\t\tbuildPhases = (")
                for phase_id in target_data.get('buildPhases', []):
                    lines.append(f"\t\t\t\t{phase_id},")
                lines.append(f"\t\t\t);")
                lines.append(f"\t\t\tbuildRules = (")
                lines.append(f"\t\t\t);")
                lines.append(f"\t\t\tdependencies = (")
                lines.append(f"\t\t\t);")
                lines.append(f'\t\t\tname = "{target_name}";')
                lines.append(f"\t\t\tproductName = \"{target_data.get('productName', target_name)}\";")
                lines.append(f"\t\t\tproductReference = {target_data.get('productReference')};")
                lines.append(f"\t\t\tproductType = \"{target_data.get('productType', 'com.apple.product-type.application')}\";")
                lines.append(f"\t\t}};")
            lines.append("/* End PBXNativeTarget section */")
            lines.append("")

        # Generate PBXProject section
        project_obj = self.analysis.get('project_object', {})
        if project_obj:
            lines.append("/* Begin PBXProject section */")
            project_id = list(project_obj.keys())[0] if project_obj else self.generate_id("project")
            project_data = project_obj.get(project_id, {})

            lines.append(f"\t\t{project_id} /* Project object */ = {{")
            lines.append(f"\t\t\tisa = PBXProject;")
            lines.append(f"\t\t\tattributes = {{")
            attributes = project_data.get('attributes', {})
            lines.append(f"\t\t\t\tBuildIndependentTargetsInParallel = {attributes.get('BuildIndependentTargetsInParallel', 1)};")
            lines.append(f"\t\t\t\tLastSwiftUpdateCheck = {attributes.get('LastSwiftUpdateCheck', 1500)};")
            lines.append(f"\t\t\t\tLastUpgradeCheck = {attributes.get('LastUpgradeCheck', 1500)};")
            lines.append(f"\t\t\t}};")
            lines.append(f'\t\t\tbuildConfigurationList = {project_data.get("buildConfigurationList")};')
            lines.append(f'\t\t\tcompatibilityVersion = "{project_data.get("compatibilityVersion", "Xcode 14.0")}";')
            lines.append(f'\t\t\tdevelopmentRegion = {project_data.get("developmentRegion", "en")};')
            lines.append(f'\t\t\thasScannedForEncodings = {project_data.get("hasScannedForEncodings", 0)};')
            lines.append(f'\t\t\tmainGroup = {root_group_id};')
            lines.append(f'\t\t\tproductRefGroup = {project_data.get("productRefGroup")};')
            lines.append(f'\t\t\tprojectDirPath = "";')
            lines.append(f'\t\t\tprojectRoot = "";')
            lines.append(f"\t\t\ttargets = (")
            for target_id in project_data.get('targets', []):
                lines.append(f"\t\t\t\t{target_id},")
            lines.append(f"\t\t\t);")
            lines.append(f"\t\t}};")
            lines.append("/* End PBXProject section */")
            lines.append("")

        # Generate PBXResourcesBuildPhase section
        resources_phase = self.analysis.get('resources_build_phase', {})
        if resources_phase:
            lines.append("/* Begin PBXResourcesBuildPhase section */")
            for phase_id, phase_data in resources_phase.items():
                lines.append(f"\t\t{phase_id} /* Resources */ = {{")
                lines.append(f"\t\t\tisa = PBXResourcesBuildPhase;")
                lines.append(f"\t\t\tbuildActionMask = {phase_data.get('buildActionMask', 2147483647)};")
                lines.append(f"\t\t\tfiles = (")
                for file_id in phase_data.get('files', []):
                    lines.append(f"\t\t\t\t{file_id},")
                lines.append(f"\t\t\t);")
                lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = {phase_data.get('runOnlyForDeploymentPostprocessing', 0)};")
                lines.append(f"\t\t}};")
            lines.append("/* End PBXResourcesBuildPhase section */")
            lines.append("")

        # Generate PBXSourcesBuildPhase section
        sources_phase = self.analysis.get('sources_build_phase', {})
        if sources_phase:
            lines.append("/* Begin PBXSourcesBuildPhase section */")
            for phase_id, phase_data in sources_phase.items():
                lines.append(f"\t\t{phase_id} /* Sources */ = {{")
                lines.append(f"\t\t\tisa = PBXSourcesBuildPhase;")
                lines.append(f"\t\t\tbuildActionMask = {phase_data.get('buildActionMask', 2147483647)};")
                lines.append(f"\t\t\tfiles = (")
                for file_id in phase_data.get('files', []):
                    lines.append(f"\t\t\t\t{file_id},")
                lines.append(f"\t\t\t);")
                lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = {phase_data.get('runOnlyForDeploymentPostprocessing', 0)};")
                lines.append(f"\t\t}};")
            lines.append("/* End PBXSourcesBuildPhase section */")
            lines.append("")

        # Generate XCBuildConfiguration section
        build_configs = self.analysis.get('build_configurations', {})
        if build_configs:
            lines.append("/* Begin XCBuildConfiguration section */")
            for config_id, config_data in build_configs.items():
                config_name = config_data.get('name', 'Debug')
                lines.append(f"\t\t{config_id} /* {config_name} */ = {{")
                lines.append(f"\t\t\tisa = XCBuildConfiguration;")
                lines.append(f"\t\t\tbuildSettings = {{")

                settings = config_data.get('buildSettings', {})

                # Ensure critical settings are preserved
                settings['PRODUCT_BUNDLE_IDENTIFIER'] = self.bundle_id
                settings['DEVELOPMENT_TEAM'] = self.team_id
                settings['MARKETING_VERSION'] = self.marketing_version
                settings['CURRENT_PROJECT_VERSION'] = self.current_project_version

                # Sort settings for consistency
                for key in sorted(settings.keys()):
                    value = settings[key]
                    if isinstance(value, list):
                        lines.append(f"\t\t\t\t{key} = (")
                        for item in value:
                            lines.append(f'\t\t\t\t\t"{item}",')
                        lines.append(f"\t\t\t\t);")
                    elif isinstance(value, str):
                        lines.append(f'\t\t\t\t{key} = "{value}";')
                    elif isinstance(value, bool):
                        lines.append(f'\t\t\t\t{key} = {"YES" if value else "NO"};')
                    else:
                        lines.append(f"\t\t\t\t{key} = {value};")

                lines.append(f"\t\t\t}};")
                lines.append(f'\t\t\tname = "{config_name}";')
                lines.append(f"\t\t}};")
            lines.append("/* End XCBuildConfiguration section */")
            lines.append("")

        # Generate XCConfigurationList section
        config_lists = self.analysis.get('configuration_lists', {})
        if config_lists:
            lines.append("/* Begin XCConfigurationList section */")
            for list_id, list_data in config_lists.items():
                comment = list_data.get('comment', 'Build configuration list')
                lines.append(f"\t\t{list_id} /* {comment} */ = {{")
                lines.append(f"\t\t\tisa = XCConfigurationList;")
                lines.append(f"\t\t\tbuildConfigurations = (")
                for config_id in list_data.get('buildConfigurations', []):
                    lines.append(f"\t\t\t\t{config_id},")
                lines.append(f"\t\t\t);")
                lines.append(f"\t\t\tdefaultConfigurationIsVisible = {list_data.get('defaultConfigurationIsVisible', 0)};")
                lines.append(f'\t\t\tdefaultConfigurationName = "{list_data.get("defaultConfigurationName", "Release")}";')
                lines.append(f"\t\t}};")
            lines.append("/* End XCConfigurationList section */")
            lines.append("")

        # Close objects and root
        lines.append("\t};")

        # Add rootObject
        project_id = list(project_obj.keys())[0] if project_obj else ""
        lines.append(f"\trootObject = {project_id} /* Project object */;")
        lines.append("}")

        return "\n".join(lines)

    def validate_project(self, content: str) -> Tuple[bool, List[str]]:
        """
        Validate the generated project content.

        Args:
            content: Generated project.pbxproj content

        Returns:
            Tuple of (is_valid, list of error messages)
        """
        print("Validating generated project...")
        errors = []

        # Check for required sections
        required_sections = [
            "Begin PBXBuildFile section",
            "Begin PBXFileReference section",
            "Begin PBXGroup section",
            "Begin PBXNativeTarget section",
            "Begin PBXProject section",
            "Begin PBXSourcesBuildPhase section",
            "Begin XCBuildConfiguration section",
        ]

        for section in required_sections:
            if section not in content:
                errors.append(f"Missing required section: {section}")

        # Check for critical settings
        if self.bundle_id not in content:
            errors.append(f"Bundle ID not found: {self.bundle_id}")

        if self.team_id not in content:
            errors.append(f"Team ID not found: {self.team_id}")

        if self.marketing_version not in content:
            errors.append(f"Marketing version not found: {self.marketing_version}")

        # Check for balanced braces
        open_braces = content.count('{')
        close_braces = content.count('}')
        if open_braces != close_braces:
            errors.append(f"Unbalanced braces: {open_braces} open, {close_braces} close")

        # Check for balanced parentheses
        open_parens = content.count('(')
        close_parens = content.count(')')
        if open_parens != close_parens:
            errors.append(f"Unbalanced parentheses: {open_parens} open, {close_parens} close")

        is_valid = len(errors) == 0

        if is_valid:
            print("  - Validation passed!")
        else:
            print(f"  - Validation failed with {len(errors)} errors")

        return is_valid, errors

    def write_project(self, content: str, output_path: Optional[Path] = None) -> None:
        """
        Write the project content to a file.

        Args:
            content: Project content to write
            output_path: Optional custom output path (defaults to temp file)
        """
        if output_path is None:
            # Write to temporary location first
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_path = self.project_path.parent / f"project.pbxproj.new.{timestamp}"

        print(f"Writing project to: {output_path}")

        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(content)

        print(f"  - Wrote {len(content)} characters")
        print(f"  - File size: {output_path.stat().st_size:,} bytes")

    def backup_original(self) -> Path:
        """
        Create a backup of the original project.pbxproj file.

        Returns:
            Path to the backup file
        """
        if not self.pbxproj_path.exists():
            raise FileNotFoundError(f"Original project file not found: {self.pbxproj_path}")

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = self.pbxproj_path.parent / f"project.pbxproj.backup.{timestamp}"

        print(f"Creating backup: {backup_path}")

        import shutil
        shutil.copy2(self.pbxproj_path, backup_path)

        return backup_path

    def rebuild(self, write_to_temp: bool = True) -> Tuple[bool, Optional[Path]]:
        """
        Execute the full rebuild process.

        Args:
            write_to_temp: If True, write to temporary file. If False, replace original.

        Returns:
            Tuple of (success, output_path)
        """
        try:
            print("\n" + "="*60)
            print("Xcode Project Rebuilder")
            print("="*60 + "\n")

            # Step 1: Load analysis
            self.load_analysis()

            # Step 2: Load group structure
            self.load_group_structure()

            # Step 3: Build maps
            self.build_file_reference_map()
            self.build_fileref_buildfile_map()

            # Step 4: Create groups from structure
            root_group_id, path_to_group = self.create_groups_from_structure()

            # Step 5: Generate project content
            content = self.generate_pbxproj_content(root_group_id)

            # Step 6: Validate
            is_valid, errors = self.validate_project(content)

            if not is_valid:
                print("\nValidation errors:")
                for error in errors:
                    print(f"  - {error}")
                return False, None

            # Step 7: Write output
            if write_to_temp:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                output_path = self.project_path.parent / f"project.pbxproj.new.{timestamp}"
            else:
                # Backup original first
                self.backup_original()
                output_path = self.pbxproj_path

            self.write_project(content, output_path)

            print("\n" + "="*60)
            print("Rebuild completed successfully!")
            print("="*60)
            print(f"\nNew project file: {output_path}")
            print(f"\nNext steps:")
            if write_to_temp:
                print(f"  1. Review the new project file")
                print(f"  2. Test it by opening in Xcode")
                print(f"  3. If successful, replace the original:")
                print(f"     cp {output_path} {self.pbxproj_path}")
            else:
                print(f"  1. Open the project in Xcode")
                print(f"  2. Verify all files are properly organized")
                print(f"  3. Test build the project")

            return True, output_path

        except Exception as e:
            print(f"\nError during rebuild: {e}")
            import traceback
            traceback.print_exc()
            return False, None


def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description='Rebuild Xcode project.pbxproj with proper organization'
    )
    parser.add_argument(
        'project_path',
        help='Path to .xcodeproj directory'
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
        '--replace',
        action='store_true',
        help='Replace the original project file (creates backup first)'
    )
    parser.add_argument(
        '--output',
        help='Custom output path for the new project file'
    )

    args = parser.parse_args()

    # Resolve paths
    project_path = Path(args.project_path).resolve()

    # If analysis/structure paths are relative, look in same dir as project
    analysis_path = Path(args.analysis)
    if not analysis_path.is_absolute():
        analysis_path = project_path.parent / args.analysis

    structure_path = Path(args.structure)
    if not structure_path.is_absolute():
        structure_path = project_path.parent / args.structure

    # Create rebuilder
    rebuilder = XcodeProjectRebuilder(
        project_path=str(project_path),
        analysis_path=str(analysis_path),
        structure_path=str(structure_path)
    )

    # Execute rebuild
    success, output_path = rebuilder.rebuild(write_to_temp=not args.replace)

    if success:
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == '__main__':
    main()
