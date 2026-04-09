# Example App

This directory contains the `VideoEditorKit` example app during the package-root migration.

Current state:

- the example app now lives under `Example/`
- the Swift package now lives at the repository root
- the supported validation flow is iOS Simulator through `xcodebuild test`
- `scripts/test-ios.sh` is the official local wrapper for that validation flow

Target state:

- `Example/VideoEditor/`
- `Example/VideoEditorTests/`
- `Example/VideoEditor.xcodeproj`
- `Example/VideoEditor.xcworkspace`
