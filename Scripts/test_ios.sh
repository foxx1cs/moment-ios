#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "${project_dir}/build"
simulator_sdk="$(xcrun --sdk iphonesimulator --show-sdk-version)"
simulator_id="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
sdk_major = sys.argv[1].split(".")[0]
for runtime in sorted(devices, reverse=True):
    if (".iOS-" + sdk_major + "-") not in runtime:
        continue
    for device in devices[runtime]:
        if "iPhone" in device["name"] and device.get("isAvailable", False):
            print(device["udid"])
            sys.exit(0)
raise SystemExit("No available iPhone simulator for the active SDK")
' "$simulator_sdk")"
xcrun simctl bootstatus "$simulator_id" -b
xcodebuild test \
    -project "${project_dir}/Moment.xcodeproj" \
    -scheme Moment \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=${simulator_id}" \
    -parallel-testing-enabled NO \
    -derivedDataPath "${project_dir}/build/TestDerivedData" \
    -resultBundlePath "${project_dir}/build/Moment-tests.xcresult" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
    2>&1 | tee "${project_dir}/build/test-ios.log"
