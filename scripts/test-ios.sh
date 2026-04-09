#!/bin/sh
set -eu

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

workspace_path="Example/VideoEditor.xcworkspace"
package_scheme="VideoEditorKit-Package"
app_scheme="VideoEditor"
simulator_name="${SIMULATOR_NAME:-iPhone 17}"
configuration="${CONFIGURATION:-Debug}"

if [ ! -d "$workspace_path" ]; then
  echo "test-ios: missing $workspace_path." >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "test-ios: 'xcodebuild' command not found." >&2
  exit 1
fi

destination="platform=iOS Simulator,name=$simulator_name"

echo "Running package tests for scheme '$package_scheme' on $simulator_name"
xcodebuild \
  -workspace "$workspace_path" \
  -scheme "$package_scheme" \
  -configuration "$configuration" \
  -destination "$destination" \
  test

echo "Running app tests for scheme '$app_scheme' on $simulator_name"
xcodebuild \
  -workspace "$workspace_path" \
  -scheme "$app_scheme" \
  -configuration "$configuration" \
  -destination "$destination" \
  test
