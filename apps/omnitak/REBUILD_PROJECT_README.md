# Xcode Project Rebuilder

## Overview

The `rebuild_project.py` script is a comprehensive Python tool that rebuilds an Xcode `project.pbxproj` file with proper organization while preserving all critical build settings, configurations, and target memberships.

## Features

- **Reads Analysis Data**: Processes `project_analysis.json` containing all file references, build files, and configurations
- **Follows Structure Plan**: Uses `group_structure.json` to create a properly organized group hierarchy
- **Preserves Critical Settings**:
  - Bundle ID: `com.engindearing.omnitak.mobile`
  - Team ID: `4HSANV485G`
  - Marketing Version: `1.3.8`
  - Current Project Version: `1.3.8`
  - All capabilities, entitlements, and signing settings
- **Maintains Build Configuration**:
  - All PBXBuildFile entries (target memberships)
  - Build phases (Sources, Resources, Frameworks)
  - Build settings for Debug and Release configurations
  - Framework search paths and other compiler settings
- **Validation**: Comprehensive validation of generated project file
- **Safety**: Writes to temporary file first, creates backups before replacing

## Prerequisites

### Required Files

Before running the rebuilder, you need two JSON files:

1. **`project_analysis.json`**: Contains analysis of the current project
   - File references and their types
   - Build files and target memberships
   - Build phases and configurations
   - Group structure (current state)

2. **`group_structure.json`**: Defines the desired group hierarchy
   - Organized folder structure
   - File placement within groups
   - Group properties (source tree, paths)

### Creating Required Files

These files should be created by separate analysis and planning agents:

```bash
# Analysis agent: Analyzes current project and exports data
python analyze_project.py OmniTAKMobile.xcodeproj

# Structure planning agent: Creates organized group structure
python plan_structure.py --based-on project_analysis.json
```

## Usage

### Basic Usage (Safe - Writes to Temporary File)

```bash
python rebuild_project.py OmniTAKMobile.xcodeproj
```

This will:
1. Read `project_analysis.json` from the project directory
2. Read `group_structure.json` from the project directory
3. Generate a new project file
4. Validate the new project file
5. Write to `project.pbxproj.new.YYYYMMDD_HHMMSS` (temporary file)

### Advanced Usage

#### Specify Custom Input Files

```bash
python rebuild_project.py OmniTAKMobile.xcodeproj \
  --analysis /path/to/custom_analysis.json \
  --structure /path/to/custom_structure.json
```

#### Replace Original Project (Creates Backup First)

```bash
python rebuild_project.py OmniTAKMobile.xcodeproj --replace
```

This will:
1. Create a backup: `project.pbxproj.backup.YYYYMMDD_HHMMSS`
2. Replace the original `project.pbxproj` file

#### Custom Output Path

```bash
python rebuild_project.py OmniTAKMobile.xcodeproj \
  --output /path/to/output/project.pbxproj
```

### Command-Line Options

```
positional arguments:
  project_path          Path to .xcodeproj directory

optional arguments:
  -h, --help           Show help message and exit
  --analysis PATH      Path to project analysis JSON file
                       (default: project_analysis.json in project dir)
  --structure PATH     Path to group structure JSON file
                       (default: group_structure.json in project dir)
  --replace            Replace the original project file
                       (creates backup first)
  --output PATH        Custom output path for new project file
```

## How It Works

### 1. Loading Phase

- **Load Analysis**: Reads `project_analysis.json` containing all existing project data
- **Load Structure**: Reads `group_structure.json` defining the desired organization
- **Build Maps**: Creates internal mappings between file paths, file references, and build files

### 2. Group Creation Phase

- Recursively creates PBXGroup entries based on `group_structure.json`
- Maps filesystem folders to Xcode groups
- Places files in their designated groups
- Creates new file references for any files not in the original analysis

### 3. Generation Phase

Generates all required Xcode project sections:
- **PBXBuildFile**: Links file references to build phases
- **PBXFileReference**: Defines all files in the project
- **PBXFrameworksBuildPhase**: Framework linking configuration
- **PBXGroup**: Group hierarchy and organization
- **PBXNativeTarget**: Target configuration
- **PBXProject**: Project-level settings
- **PBXResourcesBuildPhase**: Resource file handling
- **PBXSourcesBuildPhase**: Source file compilation
- **XCBuildConfiguration**: Build settings for Debug/Release
- **XCConfigurationList**: Configuration list references

### 4. Validation Phase

Validates the generated project:
- Checks for all required sections
- Verifies critical settings (Bundle ID, Team ID, Version)
- Validates syntax (balanced braces, parentheses)
- Reports any errors or inconsistencies

### 5. Output Phase

- Writes the validated project to the specified output location
- Creates backups if replacing the original
- Provides next steps and verification instructions

## File Format Details

### project_analysis.json

Expected structure:

```json
{
  "file_references": {
    "FILE_ID_1": {
      "isa": "PBXFileReference",
      "lastKnownFileType": "sourcecode.swift",
      "path": "Core/ContentView.swift",
      "sourceTree": "<group>"
    },
    ...
  },
  "build_files": {
    "BUILD_ID_1": {
      "isa": "PBXBuildFile",
      "fileRef": "FILE_ID_1"
    },
    ...
  },
  "groups": { ... },
  "native_targets": { ... },
  "build_configurations": { ... },
  "sources_build_phase": { ... },
  "resources_build_phase": { ... },
  "frameworks_build_phase": { ... },
  "project_object": { ... },
  "configuration_lists": { ... }
}
```

### group_structure.json

Expected structure:

```json
{
  "root": {
    "name": "OmniTAKMobile",
    "sourceTree": "<group>",
    "children": [
      {
        "name": "Core",
        "path": "OmniTAKMobile/Core",
        "sourceTree": "<group>",
        "files": [
          "Core/OmniTAKMobileApp.swift",
          "Core/ContentView.swift"
        ],
        "children": []
      },
      {
        "name": "Views",
        "path": "OmniTAKMobile/Views",
        "sourceTree": "<group>",
        "files": [
          "Views/SettingsView.swift",
          "Views/ChatView.swift"
        ],
        "children": []
      }
    ],
    "files": [
      "Resources/Info.plist",
      "Assets.xcassets"
    ]
  }
}
```

## Validation and Testing

After running the rebuilder:

### 1. Review the Generated File

```bash
# Compare file sizes
ls -lh OmniTAKMobile.xcodeproj/project.pbxproj*

# Check for critical content
grep -c "com.engindearing.omnitak.mobile" project.pbxproj.new.*
grep -c "4HSANV485G" project.pbxproj.new.*
grep -c "1.3.8" project.pbxproj.new.*
```

### 2. Test in Xcode

```bash
# Copy to test location
cp project.pbxproj.new.* test_project.pbxproj

# Open in Xcode (make a test copy of the whole project first!)
open OmniTAKMobile.xcodeproj
```

Check in Xcode:
- All files appear in the correct groups
- No missing files (red references)
- Project builds successfully
- All targets are configured correctly
- Build settings are preserved

### 3. Compare with Original

```bash
# Create a diff (may be large due to reorganization)
diff -u OmniTAKMobile.xcodeproj/project.pbxproj \
     project.pbxproj.new.* > project.diff

# Look for unexpected changes in critical settings
grep -A5 -B5 "BUNDLE_IDENTIFIER\|DEVELOPMENT_TEAM\|MARKETING_VERSION" project.diff
```

### 4. Build and Run

- Clean build folder (Shift+Cmd+K in Xcode)
- Build project (Cmd+B)
- Run on simulator
- Run on device
- Archive for distribution

## Troubleshooting

### Common Issues

#### Missing Input Files

**Error**: `FileNotFoundError: Analysis file not found`

**Solution**: Ensure `project_analysis.json` exists. Run the analysis agent first:
```bash
python analyze_project.py OmniTAKMobile.xcodeproj
```

#### Validation Failures

**Error**: `Missing required section: Begin PBXGroup section`

**Solution**: Check that `project_analysis.json` contains all necessary sections. The analysis may be incomplete.

#### Bundle ID / Team ID Not Found

**Error**: `Bundle ID not found: com.engindearing.omnitak.mobile`

**Solution**: The script will force-add these settings. If you see this error, check the `build_configurations` section in `project_analysis.json`.

#### Unbalanced Braces

**Error**: `Unbalanced braces: 1523 open, 1522 close`

**Solution**: This indicates a syntax error in generation. Check for issues in the group structure or complex nested configurations.

### Recovery

If the rebuild fails or produces an invalid project:

1. **Use the backup**: If you used `--replace`, a backup was created:
   ```bash
   cp OmniTAKMobile.xcodeproj/project.pbxproj.backup.* \
      OmniTAKMobile.xcodeproj/project.pbxproj
   ```

2. **Check Git history**: If the project is in Git:
   ```bash
   git checkout -- OmniTAKMobile.xcodeproj/project.pbxproj
   ```

3. **Review logs**: Check the script output for specific error messages

## Safety Features

1. **Read-Only by Default**: Default operation writes to a temporary file
2. **Automatic Backups**: When using `--replace`, creates timestamped backups
3. **Validation**: Comprehensive checks before writing output
4. **Dry-Run Friendly**: Can test without affecting the original project
5. **Error Reporting**: Detailed error messages with recovery suggestions

## Performance

- Typical projects (100-500 files): ~1-3 seconds
- Large projects (500-1000 files): ~3-10 seconds
- Very large projects (1000+ files): ~10-30 seconds

Memory usage scales with project size but is generally modest (<100MB for most projects).

## Limitations

1. **Requires Complete Analysis**: Both input JSON files must be complete and accurate
2. **No Incremental Updates**: Rebuilds the entire project from scratch
3. **Custom Build Rules**: Complex custom build rules may need manual verification
4. **Third-Party Integrations**: CocoaPods, Carthage, SPM should be verified after rebuild
5. **Schemes**: Xcode schemes are stored separately and are not modified

## Best Practices

1. **Always Test First**: Use the default temporary file output for initial testing
2. **Commit Before Rebuilding**: Ensure your project is committed to Git
3. **Verify in Xcode**: Always open and inspect the rebuilt project in Xcode
4. **Test Build**: Perform a clean build to verify everything works
5. **Check Teams**: Verify team-specific settings if using multiple teams

## Future Enhancements

Potential improvements for future versions:

- [ ] Support for multiple targets
- [ ] Scheme file generation/preservation
- [ ] SwiftPM dependency handling
- [ ] CocoaPods integration preservation
- [ ] Custom build rule migration
- [ ] Localization file handling
- [ ] Asset catalog organization
- [ ] Build phase script preservation with comments

## Support

For issues, questions, or contributions:

1. Check the troubleshooting section above
2. Review the validation output for specific errors
3. Examine the generated project file for inconsistencies
4. Compare with the original project structure

## License

This script is part of the OmniTAK Mobile project and follows the same license terms.

---

**Version**: 1.0.0
**Last Updated**: 2025-11-23
**Python Version**: 3.7+
