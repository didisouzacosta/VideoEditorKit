# Original Export and Saved Video Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an always-available original-quality export option, expose saved-video preview/share/delete actions in the example app, and remove the obsolete Draft marking from saved video cards.

**Architecture:** Keep the package export API centered on `VideoQuality`, adding an `original` option that maps to the existing native save render intent so edited output preserves source resolution and frame rate. Keep example-app media actions in the home/root layer, using `EditedVideoProject` as the source of persisted saved-video URLs and `VideoShareSheet` for sharing. Remove only the user-facing Draft badge and copy; preserve `EditorSessionDraft` where it still describes transient editor presentation state.

Latest refinements:

- export and save are separate toolbar items in the editor
- save displays loading and blocks the editor content while rendering the saved edited copy
- cancel remains available during save and cancels the in-flight save task
- a successful save closes the editor after the saved-video callbacks complete
- the example app persists the saved-project thumbnail from the first frame of the saved edited video copy

**Tech Stack:** Swift 6, SwiftUI, Observation, SwiftData, AVFoundation/AVKit, Swift Testing, iOS Simulator validation through `xcodebuild` or `Scripts/test-ios.sh`.

---

## Scope Notes

- "Original" means export with the current editing configuration applied while preserving the source video's native resolution and frame rate. It should not bypass edits.
- "Original" must appear in the export resolution list even when the host supplies custom export-quality availability.
- "Original" must never be blocked, including when a host accidentally passes `.blocked(.original)`.
- Saved-video menu actions should target the manual-save artifact (`savedEditedVideoURL`) first. If an older persisted project only has `exportedVideoURL`, the app may use that as a compatibility fallback for preview/share.
- Project thumbnails for manual saves should be generated from the persisted saved edited copy, using frame `0` of that ready-to-use video.
- Remove the visible "Draft" badge and related user-facing strings, not every internal use of the word `draft` where it represents a transient editing session.

## Files

- Modify: `Sources/VideoEditorKit/Export/VideoQuality.swift`
- Modify: `Sources/VideoEditorKit/API/VideoEditorPublicTypes.swift`
- Modify: `Sources/VideoEditorKit/Internal/Models/Enums/VideoEditor.swift`
- Modify: `Sources/VideoEditorKit/Internal/ViewModels/ExporterViewModel.swift`
- Modify: `Sources/VideoEditorKit/Internal/Localization/VideoEditorStrings.swift`
- Modify: `Sources/VideoEditorKit/Resources/Localizable.xcstrings`
- Modify: `Sources/VideoEditorKit/Views/Export/VideoExporterView.swift`
- Modify: `Sources/VideoEditorKit/Views/Export/VideoExporterContainerView.swift`
- Modify: `Example/VideoEditor/AppShell/Persistence/EditedVideoProject.swift`
- Modify: `Example/VideoEditor/Core/Localization/ExampleStrings.swift`
- Modify: `Example/VideoEditor/Views/RootView/EditedVideoProjectCard.swift`
- Modify: `Example/VideoEditor/Features/Home/HomeScreen.swift`
- Modify: `Example/VideoEditor/Views/RootView/RootView.swift`
- Create: `Example/VideoEditor/Features/Home/SavedVideoPreviewScreen.swift`
- Modify: `Tests/VideoEditorKitTests/Localization/PackageLocalizationTests.swift`
- Modify: `Tests/VideoEditorKitTests/VideoEditorPublicTypesTests.swift`
- Modify: `Tests/VideoEditorKitTests/ViewModels/ExporterViewModelTests.swift`
- Modify: `Tests/VideoEditorKitTests/Views/VideoExportPresentationStateTests.swift`
- Modify: `Tests/VideoEditorKitTests/Models/VideoEditorExportCharacterizationTests.swift`
- Modify: `Example/VideoEditorTests/Data/Projects/ProjectsRepositoryTests.swift`
- Modify: `Example/VideoEditorTests/Features/EditorHost/EditorSessionControllerTests.swift`

---

### Task 1: Add Original as a Public Export Quality

- [x] Add characterization tests proving the package exposes original last and never blocked.

Update `Tests/VideoEditorKitTests/VideoEditorPublicTypesTests.swift` with cases covering:

```swift
@Test
func exportQualitiesAlwaysIncludeEnabledOriginalLast() {
    let configuration = VideoEditorConfiguration(
        exportQualities: [
            .blocked(.original),
            .blocked(.high),
            .enabled(.low),
        ]
    )

    #expect(configuration.exportQualities.first?.quality == .original)
    #expect(configuration.isEnabled(.original))
    #expect(configuration.isBlocked(.original) == false)
}
```

Update `Tests/VideoEditorKitTests/Localization/PackageLocalizationTests.swift` with expectations for original:

```swift
#expect(VideoQuality.original.title == "Original")
#expect(VideoQuality.original.subtitle == "Preserves the source resolution and frame rate")
```

- [x] Run the new focused tests and confirm they fail before implementation.

Run:

```bash
xcodebuild -workspace Example/VideoEditor.xcworkspace -scheme VideoEditorKit-Package -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:VideoEditorKitTests/VideoEditorPublicTypesTests -only-testing:VideoEditorKitTests/PackageLocalizationTests test
```

Expected: failures for missing `.original` and missing localization.

- [x] Add `case original = -1` to `VideoQuality` without changing existing raw values for `low`, `medium`, and `high`.

Update `Sources/VideoEditorKit/Export/VideoQuality.swift`:

```swift
public enum VideoQuality: Int, CaseIterable, Sendable {
    case original = -1
    case low = 0
    case medium = 1
    case high = 2
}
```

Set `order` so `.original` sorts last, add `title`, `subtitle`, and a helper:

```swift
public var isOriginal: Bool {
    self == .original
}
```

For source-independent properties such as `size`, `portraitSize`, and `frameRate`, keep deterministic fallback values equal to `.high` and document that the renderer resolves actual source values when `isOriginal` is true.

- [x] Normalize export-quality availability so original is always enabled and present.

Update `ExportQualityAvailability.allEnabled` and `premiumLocked` to include `.enabled(.original)` last. In `ExportQualityAvailability.init`, force `access` to `.enabled` when `quality == .original`.

Add `VideoEditorConfiguration.normalizedExportQualities(_:)` in `Sources/VideoEditorKit/API/VideoEditorPublicTypes.swift`:

```swift
private static func normalizedExportQualities(
    _ exportQualities: [ExportQualityAvailability]
) -> [ExportQualityAvailability] {
    let original = ExportQualityAvailability.enabled(.original)
    let nonOriginalQualities = exportQualities.filter { $0.quality != .original }
    return [original] + nonOriginalQualities
}
```

Use this helper before sorting.

- [x] Add localized strings.

Update `VideoEditorStrings`:

```swift
static var qualityOriginalTitle: String {
    localized("editor.export.quality.original.title", defaultValue: "Original")
}

static var qualityOriginalSubtitle: String {
    localized(
        "editor.export.quality.original.subtitle",
        defaultValue: "Preserves the source resolution and frame rate"
    )
}
```

Add matching entries to `Sources/VideoEditorKit/Resources/Localizable.xcstrings` for existing supported locales.

- [x] Run focused tests until they pass.

Run the same `xcodebuild` command from this task. Expected: both selected suites pass.

- [x] Commit.

```bash
git add Sources/VideoEditorKit/Export/VideoQuality.swift Sources/VideoEditorKit/API/VideoEditorPublicTypes.swift Sources/VideoEditorKit/Internal/Localization/VideoEditorStrings.swift Sources/VideoEditorKit/Resources/Localizable.xcstrings Tests/VideoEditorKitTests/VideoEditorPublicTypesTests.swift Tests/VideoEditorKitTests/Localization/PackageLocalizationTests.swift
git commit -m "Add original export quality"
```

### Task 2: Route Original Export Through Native Source Quality

- [x] Add tests for original render intent.

Update `Tests/VideoEditorKitTests/Models/VideoEditorExportCharacterizationTests.swift` with a test proving `.export(.original)` resolves like `.saveNative(sourceFrameRate:)`:

```swift
@Test
func originalExportUsesSourceRenderSizeAndFrameRate() {
    let sourceSize = CGSize(width: 1080, height: 1920)
    let profile = VideoEditor.resolvedRenderProfile(
        for: sourceSize,
        editingConfiguration: .initial,
        intent: .export(.original),
        isSimulatorEnvironment: true
    )

    #expect(profile.renderSize == CGSize(width: 1080, height: 1920))
    #expect(profile.frameDuration.seconds == 1.0 / 60.0)
}
```

If the existing helper needs the true source frame rate, adjust the test to call the internal intent resolver indirectly through `startRender` injection tests in `ExporterViewModelTests`.

- [x] Run the characterization test and confirm it fails before implementation.

Run:

```bash
xcodebuild -workspace Example/VideoEditor.xcworkspace -scheme VideoEditorKit-Package -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:VideoEditorKitTests/VideoEditorExportCharacterizationTests test
```

- [x] Map `.export(.original)` to native rendering.

Update `Sources/VideoEditorKit/Internal/Models/Enums/VideoEditor.swift` so `resolvedRenderIntent(_:asset:)` converts `.export(.original)` to `.saveNative(sourceFrameRate:)`, reusing `resolvedSourceFrameRate(for:)`.

Update `resolvedRenderProfile` so `.export(.original)` also takes the same branch as `.saveNative` when called directly in tests.

- [x] Keep `ExporterViewModel` selection behavior consistent.

Because original sorts first and is enabled, `ExporterViewModel.defaultSelectedQuality(for:)` should now select `.original` for the default package configuration. Update `Tests/VideoEditorKitTests/ViewModels/ExporterViewModelTests.swift`:

```swift
#expect(viewModel.selectedQuality == .original)
```

Add a test that blocked premium config still defaults to original, not low:

```swift
#expect(viewModel.selectedQuality == .original)
#expect(viewModel.canExportVideo)
```

- [x] Run focused exporter tests.

Run:

```bash
xcodebuild -workspace Example/VideoEditor.xcworkspace -scheme VideoEditorKit-Package -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:VideoEditorKitTests/ExporterViewModelTests -only-testing:VideoEditorKitTests/VideoEditorExportCharacterizationTests test
```

- [x] Commit.

```bash
git add Sources/VideoEditorKit/Internal/Models/Enums/VideoEditor.swift Sources/VideoEditorKit/Internal/ViewModels/ExporterViewModel.swift Tests/VideoEditorKitTests/ViewModels/ExporterViewModelTests.swift Tests/VideoEditorKitTests/Models/VideoEditorExportCharacterizationTests.swift
git commit -m "Render original exports at source quality"
```

### Task 3: Update Export Sheet UI for Original Quality

- [x] Add presentation tests for original.

Update `Tests/VideoEditorKitTests/Views/VideoExportPresentationStateTests.swift` to verify original can be selected, has available accessibility state, and blocked taps are not sent for original.

- [x] Update row UI only as needed.

Keep `VideoExporterView` generic over `ExportQualityAvailability`. Because original is normalized as enabled, `PremiumQualityBadge` should never appear beside it. The existing `ExportQualityOptionRow` can remain if the label and subtitle are localized.

If visual hierarchy needs extra clarity, add a small leading icon for original with `Image(systemName: "film")`; otherwise keep the current row design to reduce risk.

- [x] Run focused UI/presentation tests.

Run:

```bash
xcodebuild -workspace Example/VideoEditor.xcworkspace -scheme VideoEditorKit-Package -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:VideoEditorKitTests/VideoExportPresentationStateTests test
```

- [x] Commit.

```bash
git add Sources/VideoEditorKit/Views/Export/VideoExporterView.swift Sources/VideoEditorKit/Views/Export/VideoExporterContainerView.swift Tests/VideoEditorKitTests/Views/VideoExportPresentationStateTests.swift
git commit -m "Show original quality in export sheet"
```

### Task 4: Add Saved Video Menu Actions in the Example App

- [x] Add model helpers for saved playback/share URL.

Update `Example/VideoEditor/AppShell/Persistence/EditedVideoProject.swift`:

```swift
var savedPlaybackVideoURL: URL? {
    if hasSavedEditedVideo {
        return savedEditedVideoURL
    }

    if hasExportedVideo {
        return exportedVideoURL
    }

    return nil
}

var canPreviewSavedVideo: Bool {
    savedPlaybackVideoURL != nil
}

var canShareSavedVideo: Bool {
    savedPlaybackVideoURL != nil
}
```

- [x] Add repository tests for saved-video URL helpers using persisted saved and exported files.

Update `Example/VideoEditorTests/Data/Projects/ProjectsRepositoryTests.swift` to create a saved edited file and assert `savedPlaybackVideoURL == savedEditedVideoURL`. Add a compatibility assertion for exported-only projects.

- [x] Create `SavedVideoPreviewScreen`.

Create `Example/VideoEditor/Features/Home/SavedVideoPreviewScreen.swift`:

```swift
import AVKit
import SwiftUI

struct SavedVideoPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss

    let url: URL

    var body: some View {
        NavigationStack {
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(ExampleStrings.projectPreview)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(ExampleStrings.close, action: dismiss.callAsFunction)
                    }
                }
        }
    }
}
```

Add `ExampleStrings.close`, `projectPreview`, `projectShare`, and `missingSavedVideo`.

- [x] Extend card/menu callbacks.

Update `EditedVideoProjectCard` public properties:

```swift
let onPreviewSavedVideo: () -> Void
let onShareSavedVideo: () -> Void
```

Update `menuButton`:

```swift
Button(action: onPreviewSavedVideo) {
    Label(ExampleStrings.projectPreview, systemImage: "play.rectangle")
}
.disabled(project.canPreviewSavedVideo == false)

Button(action: onShareSavedVideo) {
    Label(ExampleStrings.projectShare, systemImage: "square.and.arrow.up")
}
.disabled(project.canShareSavedVideo == false)
```

Keep edit and delete actions.

- [x] Wire actions through `HomeScreen` and `RootView`.

Add callbacks to `HomeScreen` and `ProjectsGridSection`:

```swift
let onPreviewSavedVideo: (EditedVideoProject) -> Void
let onShareSavedVideo: (EditedVideoProject) -> Void
```

In `RootView`, add item wrappers:

```swift
private struct ProjectVideoAction: Identifiable {
    let id: UUID
    let url: URL
}
```

Add state:

```swift
@State private var previewedVideo: ProjectVideoAction?
@State private var sharedVideo: ProjectVideoAction?
```

Add `fullScreenCover(item:)` for `SavedVideoPreviewScreen(url:)` and `sheet(item:)` for `VideoShareSheet(activityItems: [url])`.

Implement:

```swift
private func previewSavedVideo(_ project: EditedVideoProject) {
    guard let url = project.savedPlaybackVideoURL else {
        showPersistenceError(ExampleStrings.missingSavedVideo)
        return
    }

    previewedVideo = .init(id: project.id, url: url)
}

private func shareSavedVideo(_ project: EditedVideoProject) {
    guard let url = project.savedPlaybackVideoURL else {
        showPersistenceError(ExampleStrings.missingSavedVideo)
        return
    }

    sharedVideo = .init(id: project.id, url: url)
}
```

- [x] Run example app tests.

Run:

```bash
xcodebuild -workspace Example/VideoEditor.xcworkspace -scheme VideoEditor -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:VideoEditorTests/ProjectsRepositoryTests -only-testing:VideoEditorTests/EditorSessionControllerTests test
```

- [x] Commit.

```bash
git add Example/VideoEditor/AppShell/Persistence/EditedVideoProject.swift Example/VideoEditor/Core/Localization/ExampleStrings.swift Example/VideoEditor/Views/RootView/EditedVideoProjectCard.swift Example/VideoEditor/Features/Home/HomeScreen.swift Example/VideoEditor/Views/RootView/RootView.swift Example/VideoEditor/Features/Home/SavedVideoPreviewScreen.swift Example/VideoEditorTests/Data/Projects/ProjectsRepositoryTests.swift Example/VideoEditorTests/Features/EditorHost/EditorSessionControllerTests.swift
git commit -m "Add saved video preview and sharing actions"
```

### Task 5: Remove Draft Badge and User-Facing Draft Copy

- [x] Remove the Draft badge from `EditedVideoProjectCard`.

Delete `draftBadge` and the overlay that shows it when `project.hasExportedVideo == false`.

- [x] Update user-facing strings.

Remove `ExampleStrings.projectDraft` if unused. Update home copy that says "saved draft" to "saved video" or "saved edit".

Keep `EditorSessionDraft`, `editorDraft`, test names, and internal plan history unless the text is visible to users or public docs. Those names still describe transient editor state and changing them is unrelated risk.

- [x] Run a stale-string search.

Run:

```bash
rg "projectDraft|badge\\.draft|Draft|saved draft|draft or exported" Example/VideoEditor Example/VideoEditorTests README.md Docs
```

Expected: no user-facing home/card draft badge string remains. Internal `EditorSessionDraft` references may remain.

- [x] Run focused build/tests.

Run:

```bash
xcodebuild -workspace Example/VideoEditor.xcworkspace -scheme VideoEditor -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:VideoEditorTests test
```

- [x] Commit.

```bash
git add Example/VideoEditor/Core/Localization/ExampleStrings.swift Example/VideoEditor/Views/RootView/EditedVideoProjectCard.swift Example/VideoEditor/Features/Home/HomeScreen.swift
git commit -m "Remove draft badge from saved videos"
```

### Task 6: Documentation and Final Validation

- [x] Update docs.

Update:

- `README.md`: describe original export as source-resolution/FPS export.
- `Sources/VideoEditorKit/VideoEditorKit.docc/VideoEditorKit.md`: add `.original` to `VideoQuality` behavior.
- `AGENTS.md` and `CLAUDE.md`: update export qualities and example-app saved-video actions.

- [x] Run formatting.

Run:

```bash
Scripts/format-swift.sh
```

- [x] Run official validation.

Run:

```bash
Scripts/test-ios.sh
```

If the default simulator is busy, rerun with the repository-supported iOS simulator helper or `xcodebuild` destination that is available locally, then record the exact command and result.

- [x] Commit.

```bash
git add README.md Sources/VideoEditorKit/VideoEditorKit.docc/VideoEditorKit.md AGENTS.md CLAUDE.md
git commit -m "Document original export and saved video actions"
```

---

## Acceptance Checklist

- [x] Export sheet shows `Original` as the last quality option.
- [x] The first enabled resolution quality is selected by default for the default export configuration.
- [x] `Original` remains enabled when the host omits it or passes it as blocked.
- [x] `Original` export preserves source resolution and frame rate while applying current edits.
- [x] Existing low, medium, and high raw values remain stable.
- [x] Saved project cards no longer show a Draft badge.
- [x] Saved project menu includes Edit, Preview, Share, and Delete.
- [x] Preview opens the saved edited video when present.
- [x] Share presents `UIActivityViewController` for the saved edited video when present.
- [x] Delete still removes the project directory and SwiftData record.
- [x] Documentation reflects original export and saved-video actions.
- [x] Documentation reflects save/export toolbar separation, save loading/cancel behavior, successful-save dismissal, and saved-video first-frame thumbnails.
- [x] iOS Simulator validation passes.
