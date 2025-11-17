#!/bin/bash

set -e

echo "🚀 Setting up OmniTAK Test Xcode Project..."

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode command line tools not found"
    echo "   Please install Xcode from the App Store"
    exit 1
fi

# Project details
PROJECT_NAME="OmniTAKTest"
BUNDLE_ID="com.engindearing.omnitak.test"
DEPLOYMENT_TARGET="15.0"

# Create project directory structure
echo "📁 Creating project structure..."
mkdir -p "$PROJECT_NAME.xcodeproj"

# Generate project.pbxproj
cat > "$PROJECT_NAME.xcodeproj/project.pbxproj" << 'EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		A1111111111111111111111100000001 /* OmniTAKTestApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1111111111111111111111100000011 /* OmniTAKTestApp.swift */; };
		A1111111111111111111111100000002 /* ContentView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1111111111111111111111100000012 /* ContentView.swift */; };
		A1111111111111111111111100000003 /* TAKService.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1111111111111111111111100000013 /* TAKService.swift */; };
		A1111111111111111111111100000004 /* OmniTAKMobile.xcframework in Frameworks */ = {isa = PBXBuildFile; fileRef = A1111111111111111111111100000021 /* OmniTAKMobile.xcframework */; };
		A1111111111111111111111100000005 /* OmniTAKMobile.xcframework in Embed Frameworks */ = {isa = PBXBuildFile; fileRef = A1111111111111111111111100000021 /* OmniTAKMobile.xcframework */; settings = {ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }; };
/* End PBXBuildFile section */

/* Begin PBXCopyFilesBuildPhase section */
		A1111111111111111111111100000031 /* Embed Frameworks */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 10;
			files = (
				A1111111111111111111111100000005 /* OmniTAKMobile.xcframework in Embed Frameworks */,
			);
			name = "Embed Frameworks";
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
		A1111111111111111111111100000011 /* OmniTAKTestApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = OmniTAKTestApp.swift; sourceTree = "<group>"; };
		A1111111111111111111111100000012 /* ContentView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ContentView.swift; sourceTree = "<group>"; };
		A1111111111111111111111100000013 /* TAKService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TAKService.swift; sourceTree = "<group>"; };
		A1111111111111111111111100000021 /* OmniTAKMobile.xcframework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; path = OmniTAKMobile.xcframework; sourceTree = "<group>"; };
		A1111111111111111111111100000041 /* OmniTAKTest.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = OmniTAKTest.app; sourceTree = BUILT_PRODUCTS_DIR; };
		A1111111111111111111111100000051 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		A1111111111111111111111100000061 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				A1111111111111111111111100000004 /* OmniTAKMobile.xcframework in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		A1111111111111111111111100000071 = {
			isa = PBXGroup;
			children = (
				A1111111111111111111111100000081 /* OmniTAKTest */,
				A1111111111111111111111100000021 /* OmniTAKMobile.xcframework */,
				A1111111111111111111111100000091 /* Products */,
			);
			sourceTree = "<group>";
		};
		A1111111111111111111111100000081 /* OmniTAKTest */ = {
			isa = PBXGroup;
			children = (
				A1111111111111111111111100000011 /* OmniTAKTestApp.swift */,
				A1111111111111111111111100000012 /* ContentView.swift */,
				A1111111111111111111111100000013 /* TAKService.swift */,
				A1111111111111111111111100000051 /* Info.plist */,
			);
			path = OmniTAKTest;
			sourceTree = "<group>";
		};
		A1111111111111111111111100000091 /* Products */ = {
			isa = PBXGroup;
			children = (
				A1111111111111111111111100000041 /* OmniTAKTest.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		A11111111111111111111111000000A1 /* OmniTAKTest */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = A11111111111111111111111000000B1 /* Build configuration list for PBXNativeTarget "OmniTAKTest" */;
			buildPhases = (
				A11111111111111111111111000000C1 /* Sources */,
				A1111111111111111111111100000061 /* Frameworks */,
				A1111111111111111111111100000031 /* Embed Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = OmniTAKTest;
			productName = OmniTAKTest;
			productReference = A1111111111111111111111100000041 /* OmniTAKTest.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		A11111111111111111111111000000D1 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {
					A11111111111111111111111000000A1 = {
						CreatedOnToolsVersion = 15.0;
					};
				};
			};
			buildConfigurationList = A11111111111111111111111000000E1 /* Build configuration list for PBXProject "OmniTAKTest" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = A1111111111111111111111100000071;
			productRefGroup = A1111111111111111111111100000091 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				A11111111111111111111111000000A1 /* OmniTAKTest */,
			);
		};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
		A11111111111111111111111000000C1 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				A1111111111111111111111100000001 /* OmniTAKTestApp.swift in Sources */,
				A1111111111111111111111100000002 /* ContentView.swift in Sources */,
				A1111111111111111111111100000003 /* TAKService.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		A11111111111111111111111000000F1 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		A1111111111111111111111100000101 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		A1111111111111111111111100000111 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				FRAMEWORK_SEARCH_PATHS = (
					"$(inherited)",
					"$(PROJECT_DIR)",
				);
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = OmniTAKTest/Info.plist;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.engindearing.omnitak.test;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		A1111111111111111111111100000121 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				FRAMEWORK_SEARCH_PATHS = (
					"$(inherited)",
					"$(PROJECT_DIR)",
				);
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = OmniTAKTest/Info.plist;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.engindearing.omnitak.test;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		A11111111111111111111111000000B1 /* Build configuration list for PBXNativeTarget "OmniTAKTest" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				A1111111111111111111111100000111 /* Debug */,
				A1111111111111111111111100000121 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		A11111111111111111111111000000E1 /* Build configuration list for PBXProject "OmniTAKTest" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				A11111111111111111111111000000F1 /* Debug */,
				A1111111111111111111111100000101 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = A11111111111111111111111000000D1 /* Project object */;
}
EOF

echo "✅ Xcode project created!"
echo ""
echo "📱 Next steps:"
echo "   1. Open the project: open OmniTAKTest.xcodeproj"
echo "   2. Select your Development Team in Signing & Capabilities"
echo "   3. Connect your iPhone and select it as the run destination"
echo "   4. Build and Run (⌘R)"
echo ""
echo "🎯 Default TAK server: 204.48.30.216:8087"
