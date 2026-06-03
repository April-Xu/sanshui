#!/usr/bin/env python3
"""生成 QoderPet.xcodeproj — 直接运行即可，无需手动在 Xcode 里配置"""

import os, uuid, json

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJ_DIR = os.path.join(ROOT, "QoderPet.xcodeproj")
os.makedirs(PROJ_DIR, exist_ok=True)

def uid(): return uuid.uuid4().hex[:24].upper()

# ── IDs ──────────────────────────────────────────────────────────────────────
PROJECT_ID      = uid()
MAIN_GROUP_ID   = uid()
SOURCES_GROUP   = uid()
RESOURCES_GROUP = uid()
PRODUCTS_GROUP  = uid()
APP_REF_ID      = uid()
TARGET_ID       = uid()
BUILD_CONFIG_LIST_PROJ  = uid()
BUILD_CONFIG_LIST_TARGET= uid()
DEBUG_PROJ_ID   = uid()
RELEASE_PROJ_ID = uid()
DEBUG_TGT_ID    = uid()
RELEASE_TGT_ID  = uid()
BUILD_PHASES_SOURCES  = uid()
BUILD_PHASES_RESOURCES= uid()
BUILD_PHASES_FRAMEWORKS= uid()
NATIVE_TARGET_DEP = uid()

SWIFT_FILES = [
    "QoderPetApp.swift",
    "PetWindowController.swift",
    "PetViewController.swift",
    "PetState.swift",
    "SpriteSheetParser.swift",
    "QoderStateMonitor.swift",
]
RESOURCE_FILES = ["spritesheet.webp"]

# Generate IDs for each file
file_ids   = {f: uid() for f in SWIFT_FILES + RESOURCE_FILES}
build_ids  = {f: uid() for f in SWIFT_FILES + RESOURCE_FILES}
plist_id   = uid()
plist_build_id = uid()

# ── PBXFileReference ─────────────────────────────────────────────────────────
def file_refs():
    lines = []
    for f in SWIFT_FILES:
        lines.append(f'\t\t{file_ids[f]} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = "<group>"; }};')
    for f in RESOURCE_FILES:
        ext = f.rsplit(".",1)[-1]
        ftype = "image.webp" if ext == "webp" else f"file.{ext}"
        lines.append(f'\t\t{file_ids[f]} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {f}; sourceTree = "<group>"; }};')
    lines.append(f'\t\t{plist_id} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};')
    lines.append(f'\t\t{APP_REF_ID} /* QoderPet.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = QoderPet.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
    return "\n".join(lines)

# ── PBXBuildFile ─────────────────────────────────────────────────────────────
def build_files():
    lines = []
    for f in SWIFT_FILES:
        lines.append(f'\t\t{build_ids[f]} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[f]} /* {f} */; }};')
    for f in RESOURCE_FILES:
        lines.append(f'\t\t{build_ids[f]} /* {f} in Resources */ = {{isa = PBXBuildFile; fileRef = {file_ids[f]} /* {f} */; }};')
    lines.append(f'\t\t{plist_build_id} /* Info.plist in Resources */ = {{isa = PBXBuildFile; fileRef = {plist_id} /* Info.plist */; }};')
    return "\n".join(lines)

PBXPROJ = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{build_files()}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{file_refs()}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{BUILD_PHASES_FRAMEWORKS} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{MAIN_GROUP_ID} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{SOURCES_GROUP} /* QoderPet */,
\t\t\t\t{PRODUCTS_GROUP} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{SOURCES_GROUP} /* QoderPet */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{chr(10).join(f"\t\t\t\t{file_ids[f]} /* {f} */," for f in SWIFT_FILES)}
\t\t\t\t{chr(10).join(f"\t\t\t\t{file_ids[f]} /* {f} */," for f in RESOURCE_FILES)}
\t\t\t\t{plist_id} /* Info.plist */,
\t\t\t);
\t\t\tpath = QoderPet;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{PRODUCTS_GROUP} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{APP_REF_ID} /* QoderPet.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{TARGET_ID} /* QoderPet */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {BUILD_CONFIG_LIST_TARGET} /* Build configuration list for PBXNativeTarget "QoderPet" */;
\t\t\tbuildPhases = (
\t\t\t\t{BUILD_PHASES_SOURCES} /* Sources */,
\t\t\t\t{BUILD_PHASES_FRAMEWORKS} /* Frameworks */,
\t\t\t\t{BUILD_PHASES_RESOURCES} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = QoderPet;
\t\t\tpackageProductDependencies = (
\t\t\t);
\t\t\tproductName = QoderPet;
\t\t\tproductReference = {APP_REF_ID} /* QoderPet.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{PROJECT_ID} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1620;
\t\t\t\tLastUpgradeCheck = 1620;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{TARGET_ID} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.2;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {BUILD_CONFIG_LIST_PROJ} /* Build configuration list for PBXProject "QoderPet" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {MAIN_GROUP_ID};
\t\t\tminimumXcodeVersion = 14.0;
\t\t\tproductRefGroup = {PRODUCTS_GROUP} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{TARGET_ID} /* QoderPet */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{BUILD_PHASES_RESOURCES} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{chr(10).join(f"\t\t\t\t{build_ids[f]} /* {f} in Resources */," for f in RESOURCE_FILES)}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{BUILD_PHASES_SOURCES} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{chr(10).join(f"\t\t\t\t{build_ids[f]} /* {f} in Sources */," for f in SWIFT_FILES)}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{DEBUG_PROJ_ID} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tMACOS_DEPLOYMENT_TARGET = 13.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{RELEASE_PROJ_ID} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tMACOS_DEPLOYMENT_TARGET = 13.0;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{DEBUG_TGT_ID} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSTDEPLOYMENT_TARGET = 13.0;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tINFOPLIST_FILE = QoderPet/Info.plist;
\t\t\t\tLE_BUNDLE_IDENTIFIER = com.qoderpet.app;
\t\t\t\tMACOS_DEPLOYMENT_TARGET = 13.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.qoderpet.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{RELEASE_TGT_ID} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSTDEPLOYMENT_TARGET = 13.0;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tINFOPLIST_FILE = QoderPet/Info.plist;
\t\t\t\tMACOS_DEPLOYMENT_TARGET = 13.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.qoderpet.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{BUILD_CONFIG_LIST_PROJ} /* Build configuration list for PBXProject "QoderPet" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{DEBUG_PROJ_ID} /* Debug */,
\t\t\t\t{RELEASE_PROJ_ID} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{BUILD_CONFIG_LIST_TARGET} /* Build configuration list for PBXNativeTarget "QoderPet" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{DEBUG_TGT_ID} /* Debug */,
\t\t\t\t{RELEASE_TGT_ID} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */

\t}};
\trootObject = {PROJECT_ID} /* Project object */;
}}
"""

out = os.path.join(PROJ_DIR, "project.pbxproj")
with open(out, "w") as f:
    f.write(PBXPROJ)
print(f"✓ 生成: {out}")
print(f"\n现在运行:")
print(f"  open \"{ROOT}/QoderPet.xcodeproj\"")
