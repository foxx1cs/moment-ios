#!/usr/bin/env python3
"""Generate the checked-in Xcode project with no third-party build tools."""
from pathlib import Path
import hashlib
import json
import plistlib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Moment.xcodeproj"
objects = {}


def ident(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()


def obj(object_name, isa, **values):
    key = ident(object_name)
    objects[key] = {"isa": isa, **values}
    return key


def ref(path, file_type=None, source_tree="<group>"):
    values = {"path": path, "sourceTree": source_tree}
    if file_type:
        values["lastKnownFileType"] = file_type
    return obj("file:" + path, "PBXFileReference", **values)


def build(name, file_ref, **extra):
    return obj("build:" + name, "PBXBuildFile", fileRef=file_ref, **extra)


def group(name, children, path=None):
    values = {"children": children, "sourceTree": "<group>"}
    values["path" if path else "name"] = path or name
    return obj("group:" + name, "PBXGroup", **values)


def phase(phase_name, kind, files, **extra):
    return obj("phase:" + phase_name, kind, buildActionMask=2147483647,
               files=files, runOnlyForDeploymentPostprocessing=0, **extra)


def config_list(name, settings, base=None):
    configs = []
    for mode in ["Debug", "Release"]:
        options = dict(settings)
        if name == "project":
            options.update({
                "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if mode == "Debug" else "-O",
                "DEBUG_INFORMATION_FORMAT": "dwarf" if mode == "Debug" else "dwarf-with-dsym",
                "ENABLE_TESTABILITY": "YES" if mode == "Debug" else "NO",
                "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)" if mode == "Debug" else "$(inherited)",
                "ONLY_ACTIVE_ARCH": "YES" if mode == "Debug" else "NO",
            })
        extra = {"baseConfigurationReference": base} if base else {}
        configs.append(obj("config:" + name + mode, "XCBuildConfiguration",
                           buildSettings=options, name=mode, **extra))
    return obj("configs:" + name, "XCConfigurationList", buildConfigurations=configs,
               defaultConfigurationIsVisible=0, defaultConfigurationName="Release")


def dependency(parent, target):
    proxy = obj("proxy:" + parent + target, "PBXContainerItemProxy",
                containerPortal=ident("project"), proxyType=1,
                remoteGlobalIDString=ident("target:" + target), remoteInfo=target)
    return obj("dependency:" + parent + target, "PBXTargetDependency",
               target=ident("target:" + target), targetProxy=proxy)


def write_plist(path, value):
    with (ROOT / path).open("wb") as stream:
        plistlib.dump(value, stream, sort_keys=False)


def generate():
    PROJECT.mkdir(exist_ok=True)
    file_groups = {}
    refs = {}
    for folder in ["Moment", "Shared", "MomentWidgets", "MomentTests", "MomentUITests"]:
        children = []
        for path in sorted((ROOT / folder).glob("*.swift")):
            item = ref(folder + "/" + path.name, "sourcecode.swift")
            children.append(item)
            refs[folder + "/" + path.name] = item
        file_groups[folder] = children

    assets = ref("Moment/Assets.xcassets", "folder.assetcatalog")
    privacy = ref("Moment/PrivacyInfo.xcprivacy", "text.xml")
    localizations = ref("Localization/Localizable.xcstrings", "text.json")
    file_groups["Localization"] = [localizations]
    file_groups["Moment"].extend([assets, privacy])
    base = ref("Config/Shared.xcconfig", "text.xcconfig")
    config_files = [base]
    for name in ["Moment-Info.plist", "Widgets-Info.plist", "Moment.entitlements"]:
        config_files.append(ref("Config/" + name, "text.plist.xml"))
    products = {}
    for name, suffix, file_type in [("Moment", ".app", "wrapper.application"),
                                    ("MomentWidgets", ".appex", "wrapper.app-extension"),
                                    ("MomentTests", ".xctest", "wrapper.cfbundle"),
                                    ("MomentUITests", ".xctest", "wrapper.cfbundle")]:
        products[name] = obj("product:" + name, "PBXFileReference", explicitFileType=file_type,
                             includeInIndex=0, path=name + suffix, sourceTree="BUILT_PRODUCTS_DIR")
    groups = [group(name, children) for name, children in file_groups.items()]
    groups += [group("Config", config_files), group("Products", list(products.values()))]
    root_group = group("root", groups + [ref("README.md", "net.daringfireball.markdown")])

    shared_paths = sorted(path for path in refs if path.startswith("Shared/"))
    target_settings = {
        "Moment": {
            "PRODUCT_BUNDLE_IDENTIFIER": "$(MOMENT_BUNDLE_PREFIX)",
            "INFOPLIST_FILE": "Config/Moment-Info.plist",
            "CODE_SIGN_ENTITLEMENTS": "Config/Moment.entitlements",
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
            "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
            "ENABLE_PREVIEWS": "YES",
            "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
        },
        "MomentWidgets": {
            "PRODUCT_BUNDLE_IDENTIFIER": "$(MOMENT_BUNDLE_PREFIX).widgets",
            "INFOPLIST_FILE": "Config/Widgets-Info.plist",
            "CODE_SIGN_ENTITLEMENTS": "Config/Moment.entitlements",
            "APPLICATION_EXTENSION_API_ONLY": "YES",
            "SKIP_INSTALL": "YES",
            "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"],
        },
        "MomentTests": {
            "PRODUCT_BUNDLE_IDENTIFIER": "$(MOMENT_BUNDLE_PREFIX).tests",
            "GENERATE_INFOPLIST_FILE": "YES",
            "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/Moment.app/Moment",
            "BUNDLE_LOADER": "$(TEST_HOST)",
            "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"],
        },
        "MomentUITests": {
            "PRODUCT_BUNDLE_IDENTIFIER": "$(MOMENT_BUNDLE_PREFIX).uitests",
            "GENERATE_INFOPLIST_FILE": "YES",
            "TEST_TARGET_NAME": "Moment",
            "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"],
        },
    }
    targets = []
    for name, settings in target_settings.items():
        own = sorted(path for path in refs if path.startswith(name + "/"))
        paths = own + (shared_paths if name not in {"MomentTests", "MomentUITests"} else [])
        sources = phase(name + ":sources", "PBXSourcesBuildPhase",
                        [build(name + ":" + path, refs[path]) for path in paths])
        frameworks = phase(name + ":frameworks", "PBXFrameworksBuildPhase", [])
        resource_files = (
            [build(name + ":assets", assets), build(name + ":privacy", privacy),
             build(name + ":localizations", localizations)]
            if name == "Moment" else
            [build(name + ":localizations", localizations)]
            if name == "MomentWidgets" else []
        )
        resources = phase(name + ":resources", "PBXResourcesBuildPhase", resource_files)
        phases = [sources, frameworks, resources]
        dependencies = []
        if name == "Moment":
            embedded = build("embed:widgets", products["MomentWidgets"],
                             settings={"ATTRIBUTES": ["RemoveHeadersOnCopy"]})
            phases.append(phase("embed:widgets", "PBXCopyFilesBuildPhase", [embedded],
                                dstPath="", dstSubfolderSpec=13, name="Embed App Extensions"))
            dependencies.append(dependency(name, "MomentWidgets"))
        elif name in {"MomentTests", "MomentUITests"}:
            dependencies.append(dependency(name, "Moment"))
        settings.update({"PRODUCT_NAME": "$(TARGET_NAME)", "SWIFT_EMIT_LOC_STRINGS": "YES"})
        targets.append(obj("target:" + name, "PBXNativeTarget",
                           buildConfigurationList=config_list(name, settings, base),
                           buildPhases=phases, buildRules=[], dependencies=dependencies,
                           name=name, productName=name, productReference=products[name],
                           productType={"Moment": "com.apple.product-type.application",
                                        "MomentWidgets": "com.apple.product-type.app-extension",
                                        "MomentTests": "com.apple.product-type.bundle.unit-test",
                                        "MomentUITests": "com.apple.product-type.bundle.ui-testing"}[name]))

    project_configs = config_list("project", {
        "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
        "SDKROOT": "iphoneos", "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17", "SWIFT_VERSION": "5.0",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    })
    root = obj("project", "PBXProject", attributes={
        "BuildIndependentTargetsInParallel": "YES", "LastUpgradeCheck": "1600",
        "TargetAttributes": {
            ident("target:Moment"): {"CreatedOnToolsVersion": "16.0", "SystemCapabilities": {
                "com.apple.ApplicationGroups.iOS": {"enabled": 1}}},
            ident("target:MomentWidgets"): {"CreatedOnToolsVersion": "16.0", "SystemCapabilities": {
                "com.apple.ApplicationGroups.iOS": {"enabled": 1}}},
            ident("target:MomentTests"): {"CreatedOnToolsVersion": "16.0", "TestTargetID": ident("target:Moment")},
            ident("target:MomentUITests"): {"CreatedOnToolsVersion": "16.0", "TestTargetID": ident("target:Moment")},
        }}, buildConfigurationList=project_configs, compatibilityVersion="Xcode 14.0",
        developmentRegion="ru", hasScannedForEncodings=0, knownRegions=["ru", "en", "Base"],
        mainGroup=root_group, productRefGroup=ident("group:Products"),
        projectDirPath="", projectRoot="", targets=targets)

    def encode(value, depth=0):
        tabs = "\t" * depth
        if isinstance(value, dict):
            return "{\n" + "".join("\t" * (depth + 1) + encode(k) + " = " + encode(v, depth + 1) + ";\n"
                                    for k, v in value.items()) + tabs + "}"
        if isinstance(value, list):
            return "(\n" + "".join("\t" * (depth + 1) + encode(v, depth + 1) + ",\n" for v in value) + tabs + ")"
        if isinstance(value, int):
            return str(value)
        if len(value) == 24 and all(c in "0123456789ABCDEF" for c in value):
            return value
        return json.dumps(value, ensure_ascii=False)

    (PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n" + encode({
        "archiveVersion": 1, "classes": {}, "objectVersion": 56,
        "objects": objects, "rootObject": root,
    }) + "\n")

    # Also used by the platform-independent structural validator.
    (PROJECT / "project-structure.json").write_text(json.dumps(objects, indent=2, ensure_ascii=False) + "\n")

    scheme = ET.Element("Scheme", LastUpgradeVersion="1600", version="1.3")

    def buildable(parent, name):
        ET.SubElement(parent, "BuildableReference", BuildableIdentifier="primary",
                      BlueprintIdentifier=ident("target:" + name),
                      BuildableName=name + (".app" if name == "Moment" else ".xctest"),
                      BlueprintName=name, ReferencedContainer="container:Moment.xcodeproj")

    action = ET.SubElement(scheme, "BuildAction", parallelizeBuildables="YES", buildImplicitDependencies="YES")
    entries = ET.SubElement(action, "BuildActionEntries")
    entry = ET.SubElement(entries, "BuildActionEntry", buildForTesting="YES", buildForRunning="YES",
                          buildForProfiling="YES", buildForArchiving="YES", buildForAnalyzing="YES")
    buildable(entry, "Moment")
    for test_target in ["MomentTests", "MomentUITests"]:
        test_entry = ET.SubElement(entries, "BuildActionEntry", buildForTesting="YES", buildForRunning="NO",
                                   buildForProfiling="NO", buildForArchiving="NO", buildForAnalyzing="YES")
        buildable(test_entry, test_target)
    test = ET.SubElement(scheme, "TestAction", buildConfiguration="Debug",
                         selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB",
                         selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB",
                         shouldUseLaunchSchemeArgsEnv="YES")
    tests = ET.SubElement(test, "Testables")
    for test_target in ["MomentTests", "MomentUITests"]:
        buildable(ET.SubElement(tests, "TestableReference", skipped="NO"), test_target)
    launch = ET.SubElement(scheme, "LaunchAction", buildConfiguration="Debug",
                           selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB",
                           selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB",
                           launchStyle="0", useCustomWorkingDirectory="NO", ignoresPersistentStateOnLaunch="NO",
                           debugDocumentVersioning="YES", debugServiceExtension="internal",
                           allowLocationSimulation="YES")
    buildable(ET.SubElement(launch, "BuildableProductRunnable", runnableDebuggingMode="0"), "Moment")
    profile = ET.SubElement(scheme, "ProfileAction", buildConfiguration="Release",
                            shouldUseLaunchSchemeArgsEnv="YES", savedToolIdentifier="",
                            useCustomWorkingDirectory="NO", debugDocumentVersioning="YES")
    buildable(ET.SubElement(profile, "BuildableProductRunnable", runnableDebuggingMode="0"), "Moment")
    ET.SubElement(scheme, "AnalyzeAction", buildConfiguration="Debug")
    ET.SubElement(scheme, "ArchiveAction", buildConfiguration="Release", revealArchiveInOrganizer="YES")
    scheme_dir = PROJECT / "xcshareddata/xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    ET.indent(scheme)
    ET.ElementTree(scheme).write(scheme_dir / "Moment.xcscheme", encoding="UTF-8", xml_declaration=True)

    common_info = {
        "CFBundleDevelopmentRegion": "ru", "CFBundleExecutable": "$(EXECUTABLE_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)", "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": "$(PRODUCT_NAME)", "CFBundleShortVersionString": "$(MARKETING_VERSION)",
        "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)", "AppGroupIdentifier": "$(MOMENT_APP_GROUP)",
    }
    write_plist("Config/Moment-Info.plist", {
        **common_info, "CFBundleDisplayName": "Moment", "CFBundlePackageType": "APPL",
        "LSRequiresIPhoneOS": True, "UILaunchScreen": {},
        "NSSupportsLiveActivities": True,
        "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False},
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
        "UISupportedInterfaceOrientations~ipad": ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
                                                  "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"],
        "CFBundleURLTypes": [{"CFBundleURLName": "$(PRODUCT_BUNDLE_IDENTIFIER)", "CFBundleURLSchemes": ["moment"]}],
        "ITSAppUsesNonExemptEncryption": False,
    })
    write_plist("Config/Widgets-Info.plist", {
        **common_info, "CFBundleDisplayName": "Moment", "CFBundlePackageType": "XPC!",
        "NSExtension": {"NSExtensionPointIdentifier": "com.apple.widgetkit-extension"},
    })
    write_plist("Config/Moment.entitlements", {
        "com.apple.security.application-groups": ["$(MOMENT_APP_GROUP)"],
    })
    write_plist("Moment/PrivacyInfo.xcprivacy", {
        "NSPrivacyTracking": False, "NSPrivacyCollectedDataTypes": [],
        "NSPrivacyAccessedAPITypes": [], "NSPrivacyTrackingDomains": [],
    })
    print(f"Generated {PROJECT} ({len(objects)} objects)")


if __name__ == "__main__":
    generate()
