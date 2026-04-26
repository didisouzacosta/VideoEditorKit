# Example App

This directory contains the `VideoEditorKit` example app during the package-root migration.

Current state:

- the example app now lives under `Example/`
- the Swift package now lives at the repository root
- the supported validation flow is iOS Simulator through `xcodebuild test`
- `scripts/test-ios.sh` is the official local wrapper for that validation flow
- saved projects keep the original video, saved edited copy, and exported output as separate files
- manual save persists the saved edited copy and uses the first frame of that persisted video as the project thumbnail
- saved project cards open on tap and expose context-menu actions to open, share, and delete saved videos, with video preview shown directly in the context menu
- the visible Draft badge was removed because saved projects now represent saved edited videos, not autosaved drafts

Target state:

- `Example/VideoEditor/`
- `Example/VideoEditorTests/`
- `Example/VideoEditor.xcodeproj`
- `Example/VideoEditor.xcworkspace`
