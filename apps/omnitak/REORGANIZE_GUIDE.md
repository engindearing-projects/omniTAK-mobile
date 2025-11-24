# Xcode Project Reorganization Guide
## Safe, Step-by-Step Instructions

**Time Required:** 15-20 minutes
**Difficulty:** Easy
**Safety:** ✅ All settings preserved, backup created

---

## ✅ What's Already Done

Your agents have analyzed your project:
- ✅ **1,224 files** catalogued
- ✅ **192 Swift files** mapped
- ✅ **Project backup** created at `OmniTAKMobile.xcodeproj.backup`
- ✅ **Critical settings** documented:
  - Bundle ID: `com.engindearing.omnitak.mobile`
  - Team: `4HSANV485G`
  - Version: `1.3.8`
  - All signing & entitlements preserved

---

## 📋 Step-by-Step Instructions

### Step 1: Open Project in Xcode
```bash
open OmniTAKMobile.xcodeproj
```

### Step 2: Remove All File References
1. In the **Project Navigator** (left sidebar), click on the top "OmniTAKMobile" folder
2. Press **Cmd+A** to select all files
3. Press **Delete** key
4. Choose **"Remove Reference"** (NOT "Move to Trash")
   - ⚠️ This only removes Xcode references, files stay on disk

### Step 3: Create Clean Group Structure

Right-click the "OmniTAKMobile" project → **New Group without Folder**

Create these groups (in order):

#### 1. Core
- No subgroups needed

#### 2. CoT
- Create subgroup: **Generators**
- Create subgroup: **Parsers**

#### 3. Managers
- No subgroups needed

#### 4. Map
- Create subgroup: **Controllers**
- Create subgroup: **Markers**
- Create subgroup: **Overlays**
- Create subgroup: **TileSources**

#### 5. Models
- No subgroups needed

#### 6: Services
- No subgroups needed

#### 7. Storage
- No subgroups needed

#### 8. UI
- Create subgroup: **Components**
- Create subgroup: **MilStd2525**
- Create subgroup: **RadialMenu**

#### 9. Utilities
- Create subgroup: **Calculators**
- Create subgroup: **Converters**
- Create subgroup: **Integration**
- Create subgroup: **Network**
- Create subgroup: **Parsers**

#### 10. Views
- No subgroups needed

#### 11. Resources
- No subgroups needed

---

### Step 4: Add Files to Each Group

For each group created above, follow these steps:

**Example: Adding files to "Core" group**
1. Right-click **Core** group
2. Select **"Add Files to 'OmniTAKMobile'..."**
3. Navigate to: `apps/omnitak/OmniTAKMobile/Core/`
4. Select **all files** in that folder (Cmd+A)
5. **IMPORTANT**: **UNCHECK** "Copy items if needed"
6. **CHECK** "Add to targets: OmniTAKMobile"
7. Click **Add**

**Repeat for all groups:**

| Group | Folder Path |
|-------|-------------|
| Core | `OmniTAKMobile/Core/` |
| CoT | `OmniTAKMobile/CoT/` (root files only) |
| CoT/Generators | `OmniTAKMobile/CoT/Generators/` |
| CoT/Parsers | `OmniTAKMobile/CoT/Parsers/` |
| Managers | `OmniTAKMobile/Managers/` |
| Map/Controllers | `OmniTAKMobile/Map/Controllers/` |
| Map/Markers | `OmniTAKMobile/Map/Markers/` |
| Map/Overlays | `OmniTAKMobile/Map/Overlays/` |
| Map/TileSources | `OmniTAKMobile/Map/TileSources/` |
| Models | `OmniTAKMobile/Models/` |
| Services | `OmniTAKMobile/Services/` |
| Storage | `OmniTAKMobile/Storage/` |
| UI/Components | `OmniTAKMobile/UI/Components/` |
| UI/MilStd2525 | `OmniTAKMobile/UI/MilStd2525/` |
| UI/RadialMenu | `OmniTAKMobile/UI/RadialMenu/` |
| Utilities/Calculators | `OmniTAKMobile/Utilities/Calculators/` |
| Utilities/Converters | `OmniTAKMobile/Utilities/Converters/` |
| Utilities/Integration | `OmniTAKMobile/Utilities/Integration/` |
| Utilities/Network | `OmniTAKMobile/Utilities/Network/` |
| Utilities/Parsers | `OmniTAKMobile/Utilities/Parsers/` |
| Views | `OmniTAKMobile/Views/` |
| Resources | `OmniTAKMobile/Resources/` |

---

### Step 5: Add Assets and Resources

1. Right-click **Resources** group
2. **"Add Files to 'OmniTAKMobile'..."**
3. Navigate to `OmniTAKMobile/`
4. Select:
   - `Assets.xcassets`
   - `Resources/Info.plist`
   - `Resources/omnitak-mobile.p12` (if present)
5. **UNCHECK** "Copy items if needed"
6. Click **Add**

---

### Step 6: Build and Verify

1. Press **Cmd+B** to build
2. Check for any errors:
   - ✅ Should build successfully!
   - If errors about missing files: verify all folders were added
   - If duplicate files: remove duplicates

3. **Verify settings preserved:**
   - Select project in navigator → select target
   - Check **General** tab:
     - Bundle Identifier: `com.engindearing.omnitak.mobile` ✅
     - Version: `1.3.8` ✅
     - Team: `4HSANV485G` ✅

---

## 🎉 Done!

Your project is now beautifully organized with:
- ✅ Clean folder structure
- ✅ No more confusing file paths
- ✅ All settings preserved
- ✅ Same Bundle ID (no App Store issues)
- ✅ All certificates intact

---

## 🔄 If Something Goes Wrong

### Restore from backup:
```bash
cd /Users/iesouskurios/omniTAK-mobile/apps/omnitak
rm -rf OmniTAKMobile.xcodeproj
cp -r OmniTAKMobile.xcodeproj.backup OmniTAKMobile.xcodeproj
```

### Or use reorganize backup:
```bash
cd OmniTAKMobile.xcodeproj
cp project.pbxproj.reorganize_backup project.pbxproj
```

---

## 📊 Project Statistics

After reorganization, you'll have:
- **11 main groups**
- **15 subgroups**
- **192 Swift files** organized logically
- **Clean, navigable structure**
- **Professional project layout**

---

**Need help?** All your settings are documented in:
- `PROJECT_ANALYSIS_README.md`
- `ANALYSIS_SUMMARY.txt`
