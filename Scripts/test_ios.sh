#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "${project_dir}/build"
mode="${1:-all}"

prepare_simulator() {
    local simulator_sdk simulator_id
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
    echo "$simulator_id" > "${project_dir}/build/simulator-id"
    xcrun simctl bootstatus "$simulator_id" -b 2>&1 | tee "${project_dir}/build/simulator-boot.log"
}

run_xcode_tests() {
    local action="$1" simulator_id
    simulator_id="$(cat "${project_dir}/build/simulator-id")"
    local extra=()
    if [[ "$action" == "test-without-building" ]]; then
        extra=(-resultBundlePath "${project_dir}/build/Moment-tests.xcresult"
               -test-timeouts-enabled YES
               -default-test-execution-time-allowance 120
               -maximum-test-execution-time-allowance 180)
    fi
    xcodebuild "$action" \
        -project "${project_dir}/Moment.xcodeproj" \
        -scheme Moment -configuration Debug \
        -destination "platform=iOS Simulator,id=${simulator_id}" \
        -parallel-testing-enabled NO \
        -derivedDataPath "${project_dir}/build/TestDerivedData" \
        "${extra[@]}" \
        CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=- \
        ENABLE_DEBUG_DYLIB=NO \
        2>&1 | tee "${project_dir}/build/test-ios-${action}.log"
}

case "$mode" in
    prepare) prepare_simulator ;;
    build) run_xcode_tests build-for-testing ;;
    run) run_xcode_tests test-without-building ;;
    all) prepare_simulator; run_xcode_tests build-for-testing; run_xcode_tests test-without-building ;;
    *) echo "Usage: bash Scripts/test_ios.sh [prepare|build|run|all]" >&2; exit 2 ;;
esac
