#!/bin/sh

append_swift_path_if_present() {
  candidate_path="$1"

  if [ -d "$candidate_path" ]; then
    if [ -n "${resolved_swift_paths:-}" ]; then
      resolved_swift_paths="$resolved_swift_paths $candidate_path"
    else
      resolved_swift_paths="$candidate_path"
    fi
  fi
}

resolve_swift_paths() {
  resolved_swift_paths=""

  append_swift_path_if_present "Sources/VideoEditorKit"
  append_swift_path_if_present "Tests/VideoEditorKitTests"

  append_swift_path_if_present "Example/VideoEditor"
  append_swift_path_if_present "Example/VideoEditorTests"

  printf '%s\n' "$resolved_swift_paths"
}
