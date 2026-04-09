# Package Root And Example Migration Plan

## Goal

Reorganize the repository so `VideoEditorKit` is clearly package-first:

```text
Package.swift
Sources/VideoEditorKit/...
Tests/VideoEditorKitTests/...
Example/
  VideoEditor/
  VideoEditorTests/
  VideoEditor.xcodeproj
  VideoEditor.xcworkspace
```

The Swift package becomes the main product at the repository root, and the current app target becomes an example app that consumes the package as a client.

## Why This Change Makes Sense

- Swift Package Manager consumers expect `Package.swift` at the repository root.
- The package is now the main implementation surface, while the app acts as an integration example.
- The migration is complete, and the remaining work is to keep tooling and documentation aligned with the final package-first layout.
- The main risk is now drift back to transitional paths in docs, scripts, or local cleanup steps.

## Final State

```text
Package.swift
Sources/VideoEditorKit/
Tests/VideoEditorKitTests/
Example/
  VideoEditor/
  VideoEditorTests/
  VideoEditor.xcodeproj
  VideoEditor.xcworkspace
```

## Target Principles

- Keep the package import path and product name as `VideoEditorKit`.
- Keep the example app building against a local package reference during the whole migration.
- Make tooling layout-agnostic before moving folders.
- Avoid mixing structural migration with feature work.
- Validate every phase with package and app builds whenever the affected path exists.

## Migration Phases

### Phase 1: Layout-Neutral Tooling And Repo Prep

Purpose: make the repo safe to reorganize without breaking scripts or linting.

Changes:

- introduce a small shell helper that resolves current and future Swift source roots
- update formatting and lint scripts to support both layouts during transition
- update `.swiftlint.yml` includes to cover both current and future locations
- update `.gitignore` for both current and future SwiftPM and example-app artifacts
- create the `Example/` directory with a placeholder README so the target layout becomes explicit

Exit criteria:

- current package still builds from `Packages/VideoEditorKit`
- current app still builds from the existing workspace/project
- format and lint scripts work in the current layout

### Phase 2: Move The Example App Under `Example/`

Purpose: remove the example app from the repository root while keeping the package in its current subdirectory for one intermediate step.

Changes:

- move `Example/VideoEditor/` to `Example/VideoEditor/`
- move `Example/VideoEditorTests/` to `Example/VideoEditorTests/`
- move `Example/VideoEditor.xcodeproj` to `Example/VideoEditor.xcodeproj`
- recreate or move the example workspace to `Example/VideoEditor.xcworkspace`
- update the app project's local package reference from `Packages/VideoEditorKit` to the new relative path from `Example/`
- update any app-only scripts, docs, and scheme references

Exit criteria:

- example app builds from `Example/`
- example tests run from `Example/`
- package still builds from `Packages/VideoEditorKit`

### Phase 3: Move The Package To The Repository Root

Purpose: make the package the canonical repository entry point.

Changes:

- move `Package.swift` to root `Package.swift`
- move `Sources/VideoEditorKit/` to `Sources/VideoEditorKit/`
- move `Tests/VideoEditorKitTests/` to `Tests/VideoEditorKitTests/`
- move or discard package-local `.swiftpm` and `.build` artifacts
- update the example app's local package reference to the root package
- update any docs and scripts that still mention `Packages/VideoEditorKit`

Exit criteria:

- package validation is explicitly performed through the iOS package scheme, not through host macOS `swift test`
- example app resolves the root package correctly
- no active project file references `Packages/VideoEditorKit`

### Phase 4: Workspace, Docs, And CI Cleanup

Purpose: remove transitional assumptions and make the new layout the only supported one.

Changes:

- update `README.md` to present the repository as a package with an example app
- update AGENTS/docs paths that still mention `Packages/VideoEditorKit`
- simplify scripts to prefer the final layout first and eventually remove compatibility branches
- remove the `Packages/` directory if it is empty
- verify hooks, CI commands, and developer setup instructions

Exit criteria:

- no documentation points to stale paths
- local hooks no longer assume the transitional structure
- repository root cleanly reflects package-first ownership

## Risks

- breaking `XCLocalSwiftPackageReference` path resolution in `Example/VideoEditor.xcodeproj`
- leaving stale paths in scripts, hooks, or `.swiftlint.yml`
- moving the app and package in the same phase and making failures harder to isolate
- carrying over `.build` or `.swiftpm` artifacts into the new structure

## Recommended Validation Per Phase

For phases touching the package:

- do not use host macOS `swift test` as a supported validation path
- `xcodebuild` or `xcodebuildmcp` build for the package scheme
- validate the package through the shared iOS scheme `VideoEditorKit-Package`

For phases touching the example app:

- build the example app scheme on iOS Simulator
- run the example test scheme on iOS Simulator

## Phase 1 Status

- [x] migration plan documented
- [x] target `Example/` directory created
- [x] tooling updated to support current and future layouts
- [x] structural move of the example app
- [x] structural move of the package to the repository root

## Phase 2 Status

- [x] moved `Example/VideoEditor/` to `Example/VideoEditor/`
- [x] moved `Example/VideoEditorTests/` to `Example/VideoEditorTests/`
- [x] moved `Example/VideoEditor.xcodeproj` to `Example/VideoEditor.xcodeproj`
- [x] moved the workspace to `Example/VideoEditor.xcworkspace`
- [x] updated the example app package reference to `../Packages/VideoEditorKit`
- [x] app build and tests validated from `Example/VideoEditor.xcworkspace`
- [x] local package resolution validated from `Example/VideoEditor.xcworkspace`
- [x] update root-level docs that still point to the old example-app path

## Phase 3 Status

- [x] moved `Package.swift` to the repository root
- [x] moved `Sources/VideoEditorKit/` to the repository root
- [x] moved `Tests/VideoEditorKitTests/` to the repository root
- [x] updated the example app local package reference from `../Packages/VideoEditorKit` to `..`
- [x] updated the workspace package container reference from `../Packages/VideoEditorKit` to `..`
- [x] example app build and tests validated against the root package
- [x] shared package workspace scheme `VideoEditorKit-Package` validated against the root package
- [x] package validation was consolidated on the shared iOS scheme instead of host macOS `swift test`
- [x] remove stale hidden SwiftPM artifacts still left under `Packages/VideoEditorKit`
- [x] update root-level docs that still point to `Packages/VideoEditorKit`

## Phase 4 Status

- [x] README presents the repository as package-first with an example app
- [x] AGENTS and active docs point to the final root package and `Example/` app layout
- [x] scripts and SwiftLint configuration use only the final layout
- [x] stale `Packages/` build artifacts and directory removed
- [x] hooks still validate the repository root scripts and docs successfully
