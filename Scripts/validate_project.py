#!/usr/bin/env python3
"""Structural checks; deliberately not a replacement for xcodebuild test."""
from pathlib import Path
import json
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def check(condition, description):
    if not condition:
        raise AssertionError(description)


def plist(path):
    with (ROOT / path).open("rb") as stream:
        return plistlib.load(stream)


def main():
    project_dir = ROOT / "Moment.xcodeproj"
    objects = json.loads((project_dir / "project-structure.json").read_text())
    try:
        from openstep_parser import OpenStepDecoder
    except ImportError:
        print("SKIP independent .pbxproj parse (optional openstep-parser not installed)")
    else:
        with (project_dir / "project.pbxproj").open() as stream:
            actual = OpenStepDecoder.ParseFromFile(stream)
        def canonical(value):
            if isinstance(value, dict):
                return {key: canonical(item) for key, item in value.items()}
            if isinstance(value, list):
                return [canonical(item) for item in value]
            return str(value)
        check(canonical(actual["objects"]) == canonical(objects), "Project differs from structural manifest")
        check(actual["rootObject"] in objects, "Missing root project")
        print("PASS independent OpenStep project parse")

    single_refs = {"fileRef", "containerPortal", "target", "targetProxy", "mainGroup",
                   "productRefGroup", "productReference", "baseConfigurationReference", "buildConfigurationList"}
    list_refs = {"children", "files", "targets", "buildConfigurations", "buildPhases", "dependencies"}
    for key, obj in objects.items():
        for field, value in obj.items():
            if field in single_refs:
                check(value in objects, f"Dangling {field} in {key}")
            elif field in list_refs:
                check(all(item in objects for item in value), f"Dangling {field} in {key}")
        if obj["isa"] == "PBXFileReference" and obj.get("sourceTree") == "<group>":
            check((ROOT / obj["path"]).exists(), f"Missing resource: {obj['path']}")
    print(f"PASS {len(objects)} project objects, references and file paths")

    targets = {obj["name"]: obj for obj in objects.values() if obj["isa"] == "PBXNativeTarget"}
    check(set(targets) == {"Moment", "MomentWidgets", "MomentTests"}, "Incorrect targets")
    shared = {str(path.relative_to(ROOT)) for path in (ROOT / "Shared").glob("*.swift")}
    for name, target in targets.items():
        phases = [objects[key] for key in target["buildPhases"]]
        source_phases = [obj for obj in phases if obj["isa"] == "PBXSourcesBuildPhase"]
        check(len(source_phases) == 1, f"Source phase missing in {name}")
        sources = {objects[objects[key]["fileRef"]]["path"] for key in source_phases[0]["files"]}
        expected = {str(path.relative_to(ROOT)) for path in (ROOT / name).glob("*.swift")}
        if name != "MomentTests":
            expected |= shared
        check(sources == expected, f"Incorrect source membership in {name}")
        configs = objects[target["buildConfigurationList"]]["buildConfigurations"]
        for config_key in configs:
            config = objects[config_key]
            check(objects[config["baseConfigurationReference"]]["path"] == "Config/Shared.xcconfig",
                  f"Missing shared configuration for {name}")
            if name != "MomentTests":
                settings = config["buildSettings"]
                check(settings["CODE_SIGN_ENTITLEMENTS"] == "Config/Moment.entitlements", "Different group entitlements")
        if name == "Moment":
            copies = [obj for obj in phases if obj["isa"] == "PBXCopyFilesBuildPhase"]
            check(len(copies) == 1 and int(copies[0]["dstSubfolderSpec"]) == 13, "Extension not embedded")
            check(objects[copies[0]["files"][0]]["fileRef"] == targets["MomentWidgets"]["productReference"],
                  "Wrong embedded extension product")
            deps = [objects[objects[key]["target"]]["name"] for key in target["dependencies"]]
            check("MomentWidgets" in deps, "Missing extension build dependency")
        if name == "MomentTests":
            deps = [objects[objects[key]["target"]]["name"] for key in target["dependencies"]]
            check("Moment" in deps, "Tests missing app dependency")
    print("PASS app, embedded widget and XCTest target membership/configuration")

    app_info = plist("Config/Moment-Info.plist")
    widget_info = plist("Config/Widgets-Info.plist")
    entitlement = plist("Config/Moment.entitlements")
    group = "$(MOMENT_APP_GROUP)"
    check(app_info["AppGroupIdentifier"] == widget_info["AppGroupIdentifier"] == group, "Group identifiers differ")
    check(entitlement["com.apple.security.application-groups"] == [group], "Wrong group entitlement")
    config_text = (ROOT / "Config/Shared.xcconfig").read_text()
    check("MOMENT_APP_GROUP = group.$(MOMENT_BUNDLE_PREFIX)" in config_text, "Wrong group prefix")
    check(widget_info["NSExtension"]["NSExtensionPointIdentifier"] == "com.apple.widgetkit-extension", "Wrong extension type")
    check("moment" in app_info["CFBundleURLTypes"][0]["CFBundleURLSchemes"], "Missing deep link scheme")
    check(plist("Moment/PrivacyInfo.xcprivacy")["NSPrivacyTracking"] is False, "Unexpected tracking declaration")
    print("PASS Info.plist, deep links, privacy manifest and shared App Group")

    scheme = ET.parse(project_dir / "xcshareddata/xcschemes/Moment.xcscheme").getroot()
    check(scheme.find("LaunchAction/BuildableProductRunnable/BuildableReference").get("BlueprintName") == "Moment",
          "Wrong launch scheme")
    check(scheme.find("TestAction/Testables/TestableReference/BuildableReference").get("BlueprintName") == "MomentTests",
          "Wrong test scheme")
    for catalog in (ROOT / "Moment/Assets.xcassets").rglob("Contents.json"):
        content = json.loads(catalog.read_text())
        for entry in content.get("images", []):
            if "filename" in entry:
                file = catalog.parent / entry["filename"]
                check(file.exists(), f"Missing image {file}")
                data = file.read_bytes()
                check(data[:8] == b"\x89PNG\r\n\x1a\n", "Icon is not a PNG")
                check(int.from_bytes(data[16:20], "big") == 1024, "Incorrect icon width")
                check(int.from_bytes(data[20:24], "big") == 1024, "Incorrect icon height")
                check(data[25] == 2, "Icon must be opaque RGB")
    print("PASS shared scheme and opaque 1024px app icon")

    try:
        from tree_sitter import Language, Parser
        import tree_sitter_swift
    except ImportError:
        print("SKIP Swift syntax parse (optional tree-sitter packages not installed)")
    else:
        parser = Parser(Language(tree_sitter_swift.language()))
        files = sorted(ROOT.rglob("*.swift"))
        for path in files:
            tree = parser.parse(path.read_bytes())
            def walk(node):
                check(node.type != "ERROR" and not node.is_missing,
                      f"Swift syntax error in {path.relative_to(ROOT)} at {node.start_point}")
                for child in node.children:
                    walk(child)
            walk(tree.root_node)
        print(f"PASS Swift syntax parse ({len(files)} files; no SDK type checking)")

    tests = len(re.findall(r"func test\w+\(", (ROOT / "MomentTests/CountdownTests.swift").read_text()))
    print(f"INFO {tests} XCTest cases provided; execution requires Xcode on macOS")
    print("All structural checks passed. iOS build/device validation remains required.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"FAIL {error}", file=sys.stderr)
        sys.exit(1)
