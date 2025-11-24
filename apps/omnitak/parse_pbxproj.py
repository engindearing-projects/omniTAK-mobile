#!/usr/bin/env python3
"""
Parse Xcode project.pbxproj file and extract comprehensive project information.
"""

import re
import json
from pathlib import Path

def parse_section(content, section_name):
    """Extract a section from the pbxproj content."""
    pattern = rf'/\* Begin {section_name} section \*/\n(.*?)\n/\* End {section_name} section \*/'
    match = re.search(pattern, content, re.DOTALL)
    if match:
        return match.group(1)
    return ""

def parse_file_references(section_content):
    """Parse PBXFileReference entries."""
    references = {}
    # Pattern to match file references
    pattern = r'(\w+) /\* ([^*]*) \*/ = \{([^}]+)\};'

    for match in re.finditer(pattern, section_content):
        uuid = match.group(1)
        name = match.group(2)
        attributes = match.group(3)

        # Extract attributes
        file_ref = {
            'uuid': uuid,
            'name': name,
            'isa': 'PBXFileReference'
        }

        # Extract path
        path_match = re.search(r'path = "?([^";]+)"?;', attributes)
        if path_match:
            file_ref['path'] = path_match.group(1)

        # Extract fileType
        filetype_match = re.search(r'lastKnownFileType = ([^;]+);', attributes)
        if filetype_match:
            file_ref['fileType'] = filetype_match.group(1).strip()

        # Extract explicitFileType
        explicit_match = re.search(r'explicitFileType = ([^;]+);', attributes)
        if explicit_match:
            file_ref['explicitFileType'] = explicit_match.group(1).strip()

        # Extract sourceTree
        sourcetree_match = re.search(r'sourceTree = ([^;]+);', attributes)
        if sourcetree_match:
            file_ref['sourceTree'] = sourcetree_match.group(1).strip().replace('"', '')

        # Extract fileEncoding
        encoding_match = re.search(r'fileEncoding = (\d+);', attributes)
        if encoding_match:
            file_ref['fileEncoding'] = encoding_match.group(1)

        references[uuid] = file_ref

    return references

def parse_build_files(section_content):
    """Parse PBXBuildFile entries."""
    build_files = {}
    # Pattern to match build files
    pattern = r'(\w+) /\* ([^*]*) in ([^*]*) \*/ = \{[^}]*fileRef = (\w+)[^}]*\};'

    for match in re.finditer(pattern, section_content):
        uuid = match.group(1)
        name = match.group(2)
        phase = match.group(3)
        file_ref = match.group(4)

        build_files[uuid] = {
            'uuid': uuid,
            'name': name,
            'phase': phase,
            'fileRef': file_ref,
            'isa': 'PBXBuildFile'
        }

    return build_files

def parse_groups(section_content):
    """Parse PBXGroup entries."""
    groups = {}

    # Pattern to match group entries
    pattern = r'(\w+) (?:/\* ([^*]*) \*/ )?= \{[^}]*isa = PBXGroup;([^}]+)\};'

    for match in re.finditer(pattern, section_content, re.DOTALL):
        uuid = match.group(1)
        name = match.group(2) if match.group(2) else ""
        attributes = match.group(3)

        group = {
            'uuid': uuid,
            'name': name,
            'isa': 'PBXGroup',
            'children': []
        }

        # Extract children
        children_match = re.search(r'children = \((.*?)\);', attributes, re.DOTALL)
        if children_match:
            children_text = children_match.group(1)
            child_pattern = r'(\w+) /\* ([^*]*) \*/,'
            for child_match in re.finditer(child_pattern, children_text):
                group['children'].append({
                    'uuid': child_match.group(1),
                    'name': child_match.group(2)
                })

        # Extract path
        path_match = re.search(r'path = "?([^";]+)"?;', attributes)
        if path_match:
            group['path'] = path_match.group(1)

        # Extract sourceTree
        sourcetree_match = re.search(r'sourceTree = ([^;]+);', attributes)
        if sourcetree_match:
            group['sourceTree'] = sourcetree_match.group(1).strip().replace('"', '')

        groups[uuid] = group

    return groups

def parse_native_targets(section_content):
    """Parse PBXNativeTarget entries."""
    targets = {}

    # Pattern to match target entries
    pattern = r'(\w+) /\* ([^*]*) \*/ = \{[^}]*isa = PBXNativeTarget;([^}]+)\};'

    for match in re.finditer(pattern, section_content, re.DOTALL):
        uuid = match.group(1)
        name = match.group(2)
        attributes = match.group(3)

        target = {
            'uuid': uuid,
            'name': name,
            'isa': 'PBXNativeTarget'
        }

        # Extract buildConfigurationList
        config_match = re.search(r'buildConfigurationList = (\w+)', attributes)
        if config_match:
            target['buildConfigurationList'] = config_match.group(1)

        # Extract buildPhases
        phases_match = re.search(r'buildPhases = \((.*?)\);', attributes, re.DOTALL)
        if phases_match:
            phases_text = phases_match.group(1)
            phase_pattern = r'(\w+) /\* ([^*]*) \*/,'
            target['buildPhases'] = []
            for phase_match in re.finditer(phase_pattern, phases_text):
                target['buildPhases'].append({
                    'uuid': phase_match.group(1),
                    'name': phase_match.group(2)
                })

        # Extract productName
        product_match = re.search(r'productName = "?([^";]+)"?;', attributes)
        if product_match:
            target['productName'] = product_match.group(1)

        # Extract productType
        type_match = re.search(r'productType = "([^"]+)";', attributes)
        if type_match:
            target['productType'] = type_match.group(1)

        targets[uuid] = target

    return targets

def parse_build_configurations(section_content):
    """Parse XCBuildConfiguration entries."""
    configurations = {}

    # Pattern to match each configuration block - simplified
    # Split by configuration UUID pattern
    blocks = re.split(r'\n\t\t(\w+) /\* ([^*]+) \*/ = \{', section_content)

    for i in range(1, len(blocks), 3):
        if i + 2 <= len(blocks):
            uuid = blocks[i].strip()
            name_comment = blocks[i + 1].strip()
            content = blocks[i + 2]

            # Find the end of this configuration block
            end_match = re.search(r'(.*?)\n\t\t\};', content, re.DOTALL)
            if end_match:
                config_content = end_match.group(1)
            else:
                continue

            config = {
                'uuid': uuid,
                'name': name_comment,
                'isa': 'XCBuildConfiguration',
                'buildSettings': {}
            }

            # Extract name field
            name_match = re.search(r'name = ([^;]+);', config_content)
            if name_match:
                config['name'] = name_match.group(1).strip()

            # Extract buildSettings
            settings_match = re.search(r'buildSettings = \{(.*?)\n\t\t\t\};', config_content, re.DOTALL)
            if settings_match:
                settings_text = settings_match.group(1)

                # Parse each setting
                current_key = None
                current_value = []
                in_array = False

                for line in settings_text.split('\n'):
                    line = line.strip()
                    if not line:
                        continue

                    # New setting line
                    if '=' in line and not in_array:
                        # Save previous setting if exists
                        if current_key:
                            if len(current_value) == 1:
                                config['buildSettings'][current_key] = current_value[0]
                            else:
                                config['buildSettings'][current_key] = current_value

                        # Parse new setting
                        parts = line.split('=', 1)
                        current_key = parts[0].strip()
                        value_part = parts[1].strip()

                        # Remove trailing semicolon
                        if value_part.endswith(';'):
                            value_part = value_part[:-1].strip()

                        # Check if it's an array
                        if value_part.startswith('('):
                            in_array = True
                            if value_part.endswith(')'):
                                # Single line array
                                array_content = value_part[1:-1].strip()
                                if array_content:
                                    current_value = [v.strip().strip('"').strip(',') for v in array_content.split(',') if v.strip()]
                                else:
                                    current_value = []
                                in_array = False
                            else:
                                current_value = []
                        else:
                            # Simple value
                            if value_part.startswith('"') and value_part.endswith('"'):
                                current_value = [value_part[1:-1]]
                            else:
                                current_value = [value_part]
                    elif in_array:
                        # Continue parsing array
                        if line.endswith(');'):
                            # End of array
                            line = line[:-2]  # Remove );
                            in_array = False

                        if line.endswith(','):
                            line = line[:-1]

                        line = line.strip().strip('"')
                        if line:
                            current_value.append(line)

                # Save last setting
                if current_key:
                    if len(current_value) == 1:
                        config['buildSettings'][current_key] = current_value[0]
                    else:
                        config['buildSettings'][current_key] = current_value

            configurations[uuid] = config

    return configurations

def parse_sources_build_phase(section_content):
    """Parse PBXSourcesBuildPhase entries."""
    phases = {}

    pattern = r'(\w+) /\* Sources \*/ = \{[^}]*isa = PBXSourcesBuildPhase;[^}]*files = \((.*?)\);[^}]*\};'

    for match in re.finditer(pattern, section_content, re.DOTALL):
        uuid = match.group(1)
        files_text = match.group(2)

        phase = {
            'uuid': uuid,
            'isa': 'PBXSourcesBuildPhase',
            'files': []
        }

        # Extract file references
        file_pattern = r'(\w+) /\* ([^*]*) in Sources \*/,'
        for file_match in re.finditer(file_pattern, files_text):
            phase['files'].append({
                'uuid': file_match.group(1),
                'name': file_match.group(2)
            })

        phases[uuid] = phase

    return phases

def parse_resources_build_phase(section_content):
    """Parse PBXResourcesBuildPhase entries."""
    phases = {}

    pattern = r'(\w+) /\* Resources \*/ = \{[^}]*isa = PBXResourcesBuildPhase;[^}]*files = \((.*?)\);[^}]*\};'

    for match in re.finditer(pattern, section_content, re.DOTALL):
        uuid = match.group(1)
        files_text = match.group(2)

        phase = {
            'uuid': uuid,
            'isa': 'PBXResourcesBuildPhase',
            'files': []
        }

        # Extract file references
        file_pattern = r'(\w+) /\* ([^*]*) in Resources \*/,'
        for file_match in re.finditer(file_pattern, files_text):
            phase['files'].append({
                'uuid': file_match.group(1),
                'name': file_match.group(2)
            })

        phases[uuid] = phase

    return phases

def parse_frameworks_build_phase(section_content):
    """Parse PBXFrameworksBuildPhase entries."""
    phases = {}

    pattern = r'(\w+) /\* Frameworks \*/ = \{[^}]*isa = PBXFrameworksBuildPhase;[^}]*files = \((.*?)\);[^}]*\};'

    for match in re.finditer(pattern, section_content, re.DOTALL):
        uuid = match.group(1)
        files_text = match.group(2)

        phase = {
            'uuid': uuid,
            'isa': 'PBXFrameworksBuildPhase',
            'files': []
        }

        # Extract file references
        file_pattern = r'(\w+) /\* ([^*]*) in Frameworks \*/,'
        for file_match in re.finditer(file_pattern, files_text):
            phase['files'].append({
                'uuid': file_match.group(1),
                'name': file_match.group(2)
            })

        phases[uuid] = phase

    return phases

def extract_essential_settings(configurations):
    """Extract essential build settings."""
    essential_settings = {}

    # Group by configuration name to avoid duplicates
    configs_by_name = {}
    for uuid, config in configurations.items():
        name = config.get('name', 'Unknown')
        if name not in configs_by_name:
            configs_by_name[name] = config

    for name, config in configs_by_name.items():
        settings = config.get('buildSettings', {})

        # Extract key settings - include all important build settings
        essential = {
            'PRODUCT_BUNDLE_IDENTIFIER': settings.get('PRODUCT_BUNDLE_IDENTIFIER'),
            'DEVELOPMENT_TEAM': settings.get('DEVELOPMENT_TEAM'),
            'CODE_SIGN_IDENTITY': settings.get('CODE_SIGN_IDENTITY'),
            'CODE_SIGN_STYLE': settings.get('CODE_SIGN_STYLE'),
            'MARKETING_VERSION': settings.get('MARKETING_VERSION'),
            'CURRENT_PROJECT_VERSION': settings.get('CURRENT_PROJECT_VERSION'),
            'PRODUCT_NAME': settings.get('PRODUCT_NAME'),
            'INFOPLIST_FILE': settings.get('INFOPLIST_FILE'),
            'INFOPLIST_KEY_CFBundleDisplayName': settings.get('INFOPLIST_KEY_CFBundleDisplayName'),
            'SWIFT_VERSION': settings.get('SWIFT_VERSION'),
            'SWIFT_OBJC_BRIDGING_HEADER': settings.get('SWIFT_OBJC_BRIDGING_HEADER'),
            'IPHONEOS_DEPLOYMENT_TARGET': settings.get('IPHONEOS_DEPLOYMENT_TARGET'),
            'TARGETED_DEVICE_FAMILY': settings.get('TARGETED_DEVICE_FAMILY'),
            'ASSETCATALOG_COMPILER_APPICON_NAME': settings.get('ASSETCATALOG_COMPILER_APPICON_NAME'),
            'ENABLE_PREVIEWS': settings.get('ENABLE_PREVIEWS'),
            'FRAMEWORK_SEARCH_PATHS': settings.get('FRAMEWORK_SEARCH_PATHS'),
            'LD_RUNPATH_SEARCH_PATHS': settings.get('LD_RUNPATH_SEARCH_PATHS'),
            'SUPPORTED_PLATFORMS': settings.get('SUPPORTED_PLATFORMS'),
            'SUPPORTS_MACCATALYST': settings.get('SUPPORTS_MACCATALYST'),
        }

        # Remove None values
        essential = {k: v for k, v in essential.items() if v is not None}

        if essential:
            essential_settings[name] = essential

    return essential_settings

def main():
    # Read the project.pbxproj file
    pbxproj_path = Path('/Users/iesouskurios/omniTAK-mobile/apps/omnitak/OmniTAKMobile.xcodeproj/project.pbxproj')

    print("Reading project.pbxproj file...")
    with open(pbxproj_path, 'r', encoding='utf-8') as f:
        content = f.read()

    print("Parsing project sections...")

    # Parse all sections
    file_ref_section = parse_section(content, 'PBXFileReference')
    build_file_section = parse_section(content, 'PBXBuildFile')
    group_section = parse_section(content, 'PBXGroup')
    target_section = parse_section(content, 'PBXNativeTarget')
    config_section = parse_section(content, 'XCBuildConfiguration')
    sources_section = parse_section(content, 'PBXSourcesBuildPhase')
    resources_section = parse_section(content, 'PBXResourcesBuildPhase')
    frameworks_section = parse_section(content, 'PBXFrameworksBuildPhase')

    print("Parsing file references...")
    file_references = parse_file_references(file_ref_section)
    print(f"  Found {len(file_references)} file references")

    print("Parsing build files...")
    build_files = parse_build_files(build_file_section)
    print(f"  Found {len(build_files)} build files")

    print("Parsing groups...")
    groups = parse_groups(group_section)
    print(f"  Found {len(groups)} groups")

    print("Parsing targets...")
    targets = parse_native_targets(target_section)
    print(f"  Found {len(targets)} targets")

    print("Parsing build configurations...")
    configurations = parse_build_configurations(config_section)
    print(f"  Found {len(configurations)} configurations")

    print("Parsing build phases...")
    sources_phases = parse_sources_build_phase(sources_section)
    resources_phases = parse_resources_build_phase(resources_section)
    frameworks_phases = parse_frameworks_build_phase(frameworks_section)
    print(f"  Found {len(sources_phases)} source phases")
    print(f"  Found {len(resources_phases)} resource phases")
    print(f"  Found {len(frameworks_phases)} framework phases")

    print("Extracting essential settings...")
    essential_settings = extract_essential_settings(configurations)

    # Create file organization summary
    print("Organizing file structure...")
    file_organization = {}
    for uuid, file_ref in file_references.items():
        path = file_ref.get('path', '')
        if '/' in path:
            category = path.split('/')[0]
        else:
            category = 'Root'

        if category not in file_organization:
            file_organization[category] = {
                'count': 0,
                'files': []
            }

        file_organization[category]['count'] += 1
        file_organization[category]['files'].append({
            'uuid': uuid,
            'path': path,
            'name': file_ref.get('name', ''),
            'fileType': file_ref.get('fileType', file_ref.get('explicitFileType', 'unknown'))
        })

    # Build the comprehensive analysis
    analysis = {
        'metadata': {
            'projectName': 'OmniTAKMobile',
            'bundleIdentifier': 'com.engindearing.omnitak.mobile',
            'developmentTeam': '4HSANV485G',
            'version': '1.3.8',
            'buildVersion': '1.3.8',
            'minimumDeploymentTarget': '15.0',
            'swiftVersion': '5.0',
            'generatedDate': str(Path('/Users/iesouskurios/omniTAK-mobile/apps/omnitak/project_analysis.json').stat().st_mtime if Path('/Users/iesouskurios/omniTAK-mobile/apps/omnitak/project_analysis.json').exists() else 'N/A')
        },
        'projectInfo': {
            'totalFileReferences': len(file_references),
            'totalBuildFiles': len(build_files),
            'totalGroups': len(groups),
            'totalTargets': len(targets),
            'totalConfigurations': len(configurations),
            'totalSourceFiles': sum(1 for f in file_references.values() if f.get('fileType') == 'sourcecode.swift'),
            'totalResourceFiles': sum(1 for f in file_references.values() if 'Resources' in f.get('path', '')),
        },
        'fileOrganization': file_organization,
        'fileReferences': file_references,
        'buildFiles': build_files,
        'groups': groups,
        'targets': targets,
        'buildConfigurations': configurations,
        'buildPhases': {
            'sources': sources_phases,
            'resources': resources_phases,
            'frameworks': frameworks_phases
        },
        'essentialSettings': essential_settings
    }

    # Write the analysis to JSON
    output_path = Path('/Users/iesouskurios/omniTAK-mobile/apps/omnitak/project_analysis.json')
    print(f"\nWriting analysis to {output_path}...")

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(analysis, f, indent=2, ensure_ascii=False)

    print(f"\nAnalysis complete!")
    print(f"Total file size: {output_path.stat().st_size / 1024:.2f} KB")

    # Print summary
    print("\n=== SUMMARY ===")
    print(f"File References: {len(file_references)}")
    print(f"Build Files: {len(build_files)}")
    print(f"Groups: {len(groups)}")
    print(f"Targets: {len(targets)}")
    print(f"Build Configurations: {len(configurations)}")

    print("\n=== TARGETS ===")
    for target in targets.values():
        print(f"  - {target['name']} ({target.get('productType', 'unknown')})")

    print("\n=== ESSENTIAL SETTINGS ===")
    for config_name, settings in essential_settings.items():
        print(f"\n{config_name}:")
        for key, value in settings.items():
            print(f"  {key}: {value}")

    print("\n=== FILE ORGANIZATION ===")
    sorted_categories = sorted(file_organization.items(), key=lambda x: x[1]['count'], reverse=True)
    for category, info in sorted_categories[:15]:  # Top 15 categories
        print(f"  {category}: {info['count']} files")

    print("\n=== KEY PROJECT INFORMATION ===")
    print(f"Project Name: OmniTAKMobile")
    print(f"Bundle ID: com.engindearing.omnitak.mobile")
    print(f"Team ID: 4HSANV485G")
    print(f"Version: 1.3.8")
    print(f"Deployment Target: iOS 15.0+")
    print(f"Swift Version: 5.0")

if __name__ == '__main__':
    main()
