#!/bin/sh
set -eu

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

configuration_file=".swift-format"
default_paths="VideoEditorKit VideoEditorKitTests"

if [ ! -f "$configuration_file" ]; then
  echo "format-swift: missing $configuration_file in repository root." >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "format-swift: 'swift' command not found." >&2
  exit 1
fi

mode="${1:-}"

format_file() {
  file_path="$1"

  if [ ! -f "$file_path" ]; then
    return 0
  fi

  swift format format \
    --in-place \
    --configuration "$configuration_file" \
    "$file_path"
}

case "$mode" in
  --staged)
    staged_files="$(git diff --cached --name-only --diff-filter=ACMR -- '*.swift')"

    if [ -z "$staged_files" ]; then
      exit 0
    fi

    echo "$staged_files" | while IFS= read -r file_path; do
      [ -n "$file_path" ] || continue
      format_file "$file_path"
      git add -- "$file_path"
    done
    ;;
  --lint)
    swift format lint \
      --configuration "$configuration_file" \
      -r \
      $default_paths
    ;;
  "")
    swift format format \
      --in-place \
      --configuration "$configuration_file" \
      -r \
      $default_paths
    ;;
  *)
    echo "usage: scripts/format-swift.sh [--staged|--lint]" >&2
    exit 1
    ;;
esac
