# Validation

This project is iOS-only. Use iOS Simulator validation.

Do not use `swift test` as the main repository validation.

## Formatting

```bash
scripts/format-swift.sh
```

## Preferred Local Test

```bash
scripts/test-ios.sh
```

## Package Tests

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

## Example App Tests

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditor \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

## When To Run What

- Package-only logic: package tests.
- Example persistence, sharing, or host integration: app tests.
- Public behavior across package and example app: both.
- Swift-only formatting change: format only, unless code behavior changed.
