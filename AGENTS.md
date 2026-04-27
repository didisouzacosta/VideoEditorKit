# VideoEditorKit Agent Guide

Read this before changing code. Keep it short, current, and practical.

## Project

- iOS-only Swift package with an example app.
- Package: `Sources/VideoEditorKit`.
- Tests: `Tests/VideoEditorKitTests`.
- Example app: `Example/VideoEditor`.
- Example tests: `Example/VideoEditorTests`.
- Workspace: `Example/VideoEditor.xcworkspace`.
- Deployment target: iOS 18.6+.

## Core Docs

- Public usage: [README.md](README.md)
- Current architecture: [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md)
- Features and limits: [Docs/FEATURES.md](Docs/FEATURES.md)
- Validation: [Docs/VALIDATION.md](Docs/VALIDATION.md)

## Must Preserve

- Original, saved edited, and exported videos are separate files.
- `onSavedVideo` is the manual-save result.
- `onExportedVideoURL` is the export/share result.
- `onSaveStateChanged` is not per-edit autosave.
- `.original` export remains available.
- Pinch on the canvas only zooms and pans; rotation is explicit.
- Preview and export are not guaranteed by one shared engine.

## Coding Rules

- Prefer existing patterns.
- Keep edits scoped.
- Use Swift Testing for new tests.
- Add focused characterization tests before changing legacy behavior when practical.
- Do not use `swift test` as main validation.
- Do not add availability checks for iOS versions at or below the deployment target.
- Do not import UIKit directly from SwiftUI views; isolate bridges outside `Views/`.
- Avoid force unwraps and operational `print`.
- Preserve unrelated dirty worktree changes.

## Swift Organization

Use `// MARK: -` groups when touching Swift files.

Views:

1. `Environments`
2. `Bindables`
3. `Bindings`
4. `App Storage`
5. `Scene Storage`
6. `Focus State`
7. `Gesture State`
8. `Namespaces`
9. `States`
10. `Public Properties`
11. `Body`
12. `Private Properties`
13. `Initializer`
14. `Public Methods`
15. `Private Methods`

Non-view types:

1. `Public Properties`
2. `Private Properties`
3. `Initializer`
4. `Public Methods`
5. `Private Methods`

## Validation

Format first:

```bash
scripts/format-swift.sh
```

Preferred full validation:

```bash
scripts/test-ios.sh
```

Targeted package validation:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

Targeted example app validation:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditor \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```
