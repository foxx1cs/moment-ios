#!/bin/bash
# Build an unsigned device IPA for subsequent signing in Sideloadly.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]] || ! command -v xcodebuild >/dev/null 2>&1; then
    echo "Requires macOS and Xcode 16+; Linux cannot build this iOS project." >&2
    exit 1
fi

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="${1:-${project_dir}/build/Moment-unsigned.ipa}"
mkdir -p "$(dirname "$output")" "${project_dir}/build"
output="$(cd "$(dirname "$output")" && pwd)/$(basename "$output")"
work_dir="$(mktemp -d "${project_dir}/build/ipa-build.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

xcodebuild archive \
    -project "${project_dir}/Moment.xcodeproj" \
    -scheme Moment \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "${work_dir}/Moment.xcarchive" \
    -derivedDataPath "${work_dir}/DerivedData" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY='' \
    2>&1 | tee "${project_dir}/build/ipa-build.log"

app="${work_dir}/Moment.xcarchive/Products/Applications/Moment.app"
extension="${app}/PlugIns/MomentWidgets.appex"
for bundle in "$app" "$extension"; do
    plutil -lint "${bundle}/Info.plist"
    executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${bundle}/Info.plist")"
    test -s "${bundle}/${executable}"
    xcrun lipo -verify_arch arm64 "${bundle}/${executable}"
done

mkdir "${work_dir}/Payload"
ditto "$app" "${work_dir}/Payload/Moment.app"
ditto -c -k --keepParent "${work_dir}/Payload" "$output"
unzip -tq "$output"
echo "Unsigned IPA: ${output}"
echo "Sign with Sideloadly before installation. App Groups must remain available to both targets."
