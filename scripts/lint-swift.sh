#!/bin/sh
set -eu

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

swift_format_configuration=".swift-format"
swiftlint_configuration=".swiftlint.yml"
default_paths="VideoEditorKit VideoEditorKitTests"

if ! command -v swift >/dev/null 2>&1; then
  echo "lint-swift: 'swift' command not found." >&2
  exit 1
fi

if [ ! -f "$swift_format_configuration" ]; then
  echo "lint-swift: missing $swift_format_configuration in repository root." >&2
  exit 1
fi

if [ ! -f "$swiftlint_configuration" ]; then
  echo "lint-swift: missing $swiftlint_configuration in repository root." >&2
  exit 1
fi

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "lint-swift: 'swiftlint' is not installed. Install it with 'brew install swiftlint'." >&2
  exit 1
fi

swift format lint \
  --strict \
  --configuration "$swift_format_configuration" \
  -r \
  $default_paths

swiftlint lint \
  --no-cache \
  --config "$swiftlint_configuration"
