# External Export Sheet Modifier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a public SwiftUI `ViewModifier` that lets host apps present the same export-quality sheet outside `VideoEditorView`, then render the selected quality and continue to a share dialog.

**Architecture:** Keep the existing export UI and rendering state machine as the single source of behavior. Add a small public request/preparation model, a public sheet view that loads the source video and delegates to `VideoExporterContainerView`, and two `View` extension overloads: `isPresented` for simple hosts and `item` for list-driven flows. The example app should use the item overload from the saved-project list and open `VideoShareSheet` only after the export finishes.

**Tech Stack:** SwiftUI, Observation, AVFoundation-backed package render pipeline, Swift Testing, iOS 18.6+.

---

## File Structure

- Create `Sources/VideoEditorKit/Export/VideoExportSheetRequest.swift`
  - Public `VideoExportSheetRequest` describing a source URL, editing configuration, and optional prepared original export metadata.
  - Public `VideoExportPreparationResult` used by advanced hosts without exposing internal `ExporterViewModel`.
- Create `Sources/VideoEditorKit/Views/Export/VideoExportSheet.swift`
  - Public `VideoExportSheet` that loads `Video` from the request and reuses `VideoExporterContainerView`.
  - Internal preparation resolver for `.original` reuse and normal render fallback.
- Create `Sources/VideoEditorKit/Views/Export/View+VideoExportSheet.swift`
  - Public `View.videoExportSheet(isPresented:request:configuration:onExported:)`.
  - Public `View.videoExportSheet(item:configuration:request:onExported:)`.
- Modify `Sources/VideoEditorKit/Views/Export/VideoExporterContainerView.swift`
  - Map public `VideoExportPreparationResult` into internal `ExporterViewModel.ExportPreparationResult`.
- Modify `Example/VideoEditor/Views/RootView/RootView.swift`
  - Replace direct saved-video share with external export sheet selection, then present the existing `VideoShareSheet`.
- Modify `Docs/FEATURES.md`, `README.md`, and `Sources/VideoEditorKit/VideoEditorKit.docc/VideoEditorKit.md`
  - Document the external export sheet modifier.
- Test `Tests/VideoEditorKitTests/Views/VideoExportSheetRequestTests.swift`
  - Characterize request identity and preparation behavior.
- Test `Tests/VideoEditorKitTests/Views/VideoExportSheetModifierCompileTests.swift`
  - Compile-check the public modifier overloads.

## API Shape

The intended host use in a project list is:

```swift
@State private var exportingProject: EditedVideoProject?
@State private var sharedVideo: ProjectVideoAction?

var body: some View {
    HomeScreen(
        selectedItem: $selectedItem,
        projects: availableProjects,
        usesCompactGridLayout: horizontalSizeClass == .compact,
        onOpenProject: openProject,
        onShareSavedVideo: shareSavedVideo,
        onDeleteProject: deleteProject
    )
    .videoExportSheet(
        item: $exportingProject,
        request: exportRequest(for:),
        onExported: { exportedVideo, project in
            sharedVideo = .init(id: project.id, url: exportedVideo.url)
        }
    )
    .sheet(item: $sharedVideo) { videoAction in
        VideoShareSheet(
            activityItems: [videoAction.url],
            onCompletion: handleShareCompletion
        )
    }
}
```

---

### Task 1: Public Request And Preparation Model

**Files:**
- Create: `Sources/VideoEditorKit/Export/VideoExportSheetRequest.swift`
- Test: `Tests/VideoEditorKitTests/Views/VideoExportSheetRequestTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/VideoEditorKitTests/Views/VideoExportSheetRequestTests.swift`:

```swift
import Foundation
import Testing

@testable import VideoEditorKit

@Suite("VideoExportSheetRequestTests")
struct VideoExportSheetRequestTests {

    // MARK: - Public Methods

    @Test
    func requestDefaultsToTheSourceURLIdentityAndInitialEditingConfiguration() {
        let url = URL(fileURLWithPath: "/tmp/source.mp4")
        let request = VideoExportSheetRequest(sourceVideoURL: url)

        #expect(request.id == url.absoluteString)
        #expect(request.sourceVideoURL == url)
        #expect(request.editingConfiguration == .initial)
        #expect(request.preparedOriginalExportVideo == nil)
        #expect(request.preparedOriginalExportEditingConfiguration == nil)
    }

    @Test
    func requestKeepsThePreparedOriginalConfigurationOnlyWhenPreparedVideoExists() {
        let url = URL(fileURLWithPath: "/tmp/source.mp4")
        let preparedVideo = ExportedVideo(
            URL(fileURLWithPath: "/tmp/prepared.mp4"),
            width: 1920,
            height: 1080,
            duration: 8,
            fileSize: 1024
        )
        let editingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 1, upperBound: 6)
        )

        let request = VideoExportSheetRequest(
            id: "project-1",
            sourceVideoURL: url,
            editingConfiguration: editingConfiguration,
            preparedOriginalExportVideo: preparedVideo
        )

        #expect(request.id == "project-1")
        #expect(request.preparedOriginalExportVideo == preparedVideo)
        #expect(request.preparedOriginalExportEditingConfiguration == editingConfiguration)
    }

    @Test
    func requestUsesTheExplicitPreparedOriginalConfigurationWhenProvided() {
        let sourceURL = URL(fileURLWithPath: "/tmp/source.mp4")
        let preparedVideo = ExportedVideo(
            URL(fileURLWithPath: "/tmp/prepared.mp4"),
            width: 1920,
            height: 1080,
            duration: 8,
            fileSize: 1024
        )
        let editingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 1, upperBound: 6)
        )
        let preparedConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 2, upperBound: 5)
        )

        let request = VideoExportSheetRequest(
            sourceVideoURL: sourceURL,
            editingConfiguration: editingConfiguration,
            preparedOriginalExportVideo: preparedVideo,
            preparedOriginalExportEditingConfiguration: preparedConfiguration
        )

        #expect(request.preparedOriginalExportEditingConfiguration == preparedConfiguration)
    }

}
```

- [ ] **Step 2: Run the failing tests**

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test \
  -only-testing:VideoEditorKitTests/VideoExportSheetRequestTests
```

Expected: FAIL because `VideoExportSheetRequest` does not exist.

- [ ] **Step 3: Implement the public model**

Create `Sources/VideoEditorKit/Export/VideoExportSheetRequest.swift`:

```swift
import Foundation

/// Input used by the external export sheet to render a video outside `VideoEditorView`.
public struct VideoExportSheetRequest: Equatable, Identifiable, Sendable {

    // MARK: - Public Properties

    /// Stable identity for SwiftUI sheet presentation.
    public let id: String
    /// Local playable source video URL.
    public let sourceVideoURL: URL
    /// Editing snapshot that should be applied during export.
    public let editingConfiguration: VideoEditingConfiguration
    /// Ready-to-use video that can satisfy an `.original` export without rendering again.
    public let preparedOriginalExportVideo: ExportedVideo?
    /// Editing snapshot used to create `preparedOriginalExportVideo`.
    public let preparedOriginalExportEditingConfiguration: VideoEditingConfiguration?

    // MARK: - Initializer

    public init(
        id: String? = nil,
        sourceVideoURL: URL,
        editingConfiguration: VideoEditingConfiguration = .initial,
        preparedOriginalExportVideo: ExportedVideo? = nil,
        preparedOriginalExportEditingConfiguration: VideoEditingConfiguration? = nil
    ) {
        self.id = id ?? sourceVideoURL.absoluteString
        self.sourceVideoURL = sourceVideoURL
        self.editingConfiguration = editingConfiguration
        self.preparedOriginalExportVideo = preparedOriginalExportVideo
        self.preparedOriginalExportEditingConfiguration = preparedOriginalExportVideo.map { _ in
            preparedOriginalExportEditingConfiguration ?? editingConfiguration
        }
    }

}

/// Public preparation result used by advanced export-sheet integrations.
public enum VideoExportPreparationResult: Equatable, Sendable {

    // MARK: - Public Properties

    case render
    case usePreparedVideo(ExportedVideo)
    case cancelled

}
```

- [ ] **Step 4: Run the request tests**

Run the same `xcodebuild ... -only-testing:VideoEditorKitTests/VideoExportSheetRequestTests` command.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VideoEditorKit/Export/VideoExportSheetRequest.swift Tests/VideoEditorKitTests/Views/VideoExportSheetRequestTests.swift
git commit -m "feat: add export sheet request model"
```

---

### Task 2: Public Export Sheet View

**Files:**
- Create: `Sources/VideoEditorKit/Views/Export/VideoExportSheet.swift`
- Modify: `Sources/VideoEditorKit/Views/Export/VideoExporterContainerView.swift`
- Test: `Tests/VideoEditorKitTests/Views/VideoExportSheetRequestTests.swift`

- [ ] **Step 1: Add failing preparation tests**

Append these tests to `VideoExportSheetRequestTests`:

```swift
    @Test
    func defaultPreparationUsesPreparedOriginalWhenTheConfigurationMatches() {
        let preparedVideo = ExportedVideo(
            URL(fileURLWithPath: "/tmp/prepared.mp4"),
            width: 1920,
            height: 1080,
            duration: 8,
            fileSize: 1024
        )
        let editingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 1, upperBound: 6)
        )
        let request = VideoExportSheetRequest(
            sourceVideoURL: URL(fileURLWithPath: "/tmp/source.mp4"),
            editingConfiguration: editingConfiguration,
            preparedOriginalExportVideo: preparedVideo,
            preparedOriginalExportEditingConfiguration: editingConfiguration
        )

        let result = VideoExportSheetPreparationResolver.preparationResult(
            selectedQuality: .original,
            request: request,
            loadedOriginalVideo: nil
        )

        #expect(result == .usePreparedVideo(preparedVideo))
    }

    @Test
    func defaultPreparationRendersWhenPreparedOriginalConfigurationDiffers() {
        let preparedVideo = ExportedVideo(
            URL(fileURLWithPath: "/tmp/prepared.mp4"),
            width: 1920,
            height: 1080,
            duration: 8,
            fileSize: 1024
        )
        let request = VideoExportSheetRequest(
            sourceVideoURL: URL(fileURLWithPath: "/tmp/source.mp4"),
            editingConfiguration: VideoEditingConfiguration(trim: .init(lowerBound: 1, upperBound: 6)),
            preparedOriginalExportVideo: preparedVideo,
            preparedOriginalExportEditingConfiguration: VideoEditingConfiguration(trim: .init(lowerBound: 2, upperBound: 6))
        )

        let result = VideoExportSheetPreparationResolver.preparationResult(
            selectedQuality: .original,
            request: request,
            loadedOriginalVideo: nil
        )

        #expect(result == .render)
    }

    @Test
    func defaultPreparationUsesLoadedOriginalForInitialOriginalExport() {
        let loadedOriginal = ExportedVideo(
            URL(fileURLWithPath: "/tmp/source.mp4"),
            width: 1920,
            height: 1080,
            duration: 8,
            fileSize: 1024
        )
        let request = VideoExportSheetRequest(
            sourceVideoURL: loadedOriginal.url,
            editingConfiguration: .initial
        )

        let result = VideoExportSheetPreparationResolver.preparationResult(
            selectedQuality: .original,
            request: request,
            loadedOriginalVideo: loadedOriginal
        )

        #expect(result == .usePreparedVideo(loadedOriginal))
    }

    @Test
    func defaultPreparationRendersNonOriginalQualities() {
        let loadedOriginal = ExportedVideo(
            URL(fileURLWithPath: "/tmp/source.mp4"),
            width: 1920,
            height: 1080,
            duration: 8,
            fileSize: 1024
        )
        let request = VideoExportSheetRequest(
            sourceVideoURL: loadedOriginal.url,
            editingConfiguration: .initial
        )

        let result = VideoExportSheetPreparationResolver.preparationResult(
            selectedQuality: .low,
            request: request,
            loadedOriginalVideo: loadedOriginal
        )

        #expect(result == .render)
    }
```

- [ ] **Step 2: Run the failing tests**

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test \
  -only-testing:VideoEditorKitTests/VideoExportSheetRequestTests
```

Expected: FAIL because `VideoExportSheetPreparationResolver` does not exist.

- [ ] **Step 3: Add preparation mapping to the existing container**

Modify `Sources/VideoEditorKit/Views/Export/VideoExporterContainerView.swift` by adding this initializer below the existing initializer:

```swift
    init(
        lifecycleState: Binding<ExportLifecycleState>,
        video: Video,
        editingConfiguration: VideoEditingConfiguration,
        exportQualities: [ExportQualityAvailability] = ExportQualityAvailability.allEnabled,
        prepareForExport: @escaping (VideoQuality) async -> VideoExportPreparationResult,
        shouldShowSavingBeforeExport: @escaping (VideoQuality) -> Bool = { _ in false },
        onBlockedQualityTap: @escaping (VideoQuality) -> Void = { _ in },
        onExported: @escaping (ExportedVideo) -> Void
    ) {
        self.init(
            lifecycleState: lifecycleState,
            video: video,
            editingConfiguration: editingConfiguration,
            exportQualities: exportQualities,
            prepareForExport: { quality in
                switch await prepareForExport(quality) {
                case .render:
                    .render
                case .usePreparedVideo(let exportedVideo):
                    .usePreparedVideo(exportedVideo)
                case .cancelled:
                    .cancelled
                }
            },
            shouldShowSavingBeforeExport: shouldShowSavingBeforeExport,
            onBlockedQualityTap: onBlockedQualityTap,
            onExported: onExported
        )
    }
```

- [ ] **Step 4: Implement `VideoExportSheet`**

Create `Sources/VideoEditorKit/Views/Export/VideoExportSheet.swift`:

```swift
import SwiftUI

@MainActor
public struct VideoExportSheet: View {

    // MARK: - Environments

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - States

    @State private var exportLifecycleState: ExportLifecycleState = .active
    @State private var loadedVideo: Video?
    @State private var loadedOriginalVideo: ExportedVideo?

    // MARK: - Public Properties

    public typealias PrepareForExport = (VideoQuality) async -> VideoExportPreparationResult

    // MARK: - Body

    public var body: some View {
        Group {
            if let loadedVideo {
                VideoExporterContainerView(
                    lifecycleState: $exportLifecycleState,
                    video: loadedVideo,
                    editingConfiguration: request.editingConfiguration,
                    exportQualities: configuration.exportQualities,
                    prepareForExport: resolvedPrepareForExport,
                    onBlockedQualityTap: configuration.notifyBlockedExportQualityTap(for:),
                    onExported: onExported
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
        }
        .task(id: request.id) {
            await loadVideo()
        }
        .onChange(of: scenePhase) { _, newScenePhase in
            exportLifecycleState = .init(scenePhase: newScenePhase)
        }
        .task(id: scenePhase) {
            exportLifecycleState = .init(scenePhase: scenePhase)
        }
    }

    // MARK: - Private Properties

    private let request: VideoExportSheetRequest
    private let configuration: VideoEditorConfiguration
    private let prepareForExport: PrepareForExport?
    private let onExported: (ExportedVideo) -> Void

    private var resolvedPrepareForExport: PrepareForExport {
        if let prepareForExport {
            return prepareForExport
        }

        return { quality in
            VideoExportSheetPreparationResolver.preparationResult(
                selectedQuality: quality,
                request: request,
                loadedOriginalVideo: loadedOriginalVideo
            )
        }
    }

    // MARK: - Initializer

    public init(
        request: VideoExportSheetRequest,
        configuration: VideoEditorConfiguration = .init(),
        prepareForExport: PrepareForExport? = nil,
        onExported: @escaping (ExportedVideo) -> Void
    ) {
        self.request = request
        self.configuration = configuration
        self.prepareForExport = prepareForExport
        self.onExported = onExported
    }

    // MARK: - Private Methods

    private func loadVideo() async {
        loadedVideo = nil
        loadedOriginalVideo = nil

        let video = await Video.load(from: request.sourceVideoURL)
        loadedVideo = video
        loadedOriginalVideo = Self.loadedOriginalExportVideo(from: video)
    }

    private static func loadedOriginalExportVideo(from video: Video) -> ExportedVideo {
        ExportedVideo(
            video.url,
            width: max(video.presentationSize.width, 0),
            height: max(video.presentationSize.height, 0),
            duration: max(video.originalDuration, 0),
            fileSize: resolvedFileSize(for: video.url)
        )
    }

    private static func resolvedFileSize(for url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path())
        let sizeValue = attributes?[.size] as? NSNumber
        return max(sizeValue?.int64Value ?? 0, 0)
    }

}

enum VideoExportSheetPreparationResolver {

    // MARK: - Public Methods

    static func preparationResult(
        selectedQuality: VideoQuality,
        request: VideoExportSheetRequest,
        loadedOriginalVideo: ExportedVideo?
    ) -> VideoExportPreparationResult {
        if selectedQuality == .original,
            let preparedOriginalExportVideo = request.preparedOriginalExportVideo,
            request.preparedOriginalExportEditingConfiguration?.continuousSaveFingerprint
                == request.editingConfiguration.continuousSaveFingerprint
        {
            return .usePreparedVideo(preparedOriginalExportVideo)
        }

        if selectedQuality == .original,
            request.editingConfiguration.continuousSaveFingerprint
                == VideoEditingConfiguration.initial.continuousSaveFingerprint,
            let loadedOriginalVideo
        {
            return .usePreparedVideo(loadedOriginalVideo)
        }

        return .render
    }

}
```

- [ ] **Step 5: Run the preparation tests**

Run the same `xcodebuild ... -only-testing:VideoEditorKitTests/VideoExportSheetRequestTests` command.

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/VideoEditorKit/Views/Export/VideoExportSheet.swift Sources/VideoEditorKit/Views/Export/VideoExporterContainerView.swift Tests/VideoEditorKitTests/Views/VideoExportSheetRequestTests.swift
git commit -m "feat: add public export sheet view"
```

---

### Task 3: Public View Modifier API

**Files:**
- Create: `Sources/VideoEditorKit/Views/Export/View+VideoExportSheet.swift`
- Test: `Tests/VideoEditorKitTests/Views/VideoExportSheetModifierCompileTests.swift`

- [ ] **Step 1: Write compile coverage for both overloads**

Create `Tests/VideoEditorKitTests/Views/VideoExportSheetModifierCompileTests.swift`:

```swift
import SwiftUI
import Testing

import VideoEditorKit

@MainActor
@Suite("VideoExportSheetModifierCompileTests")
struct VideoExportSheetModifierCompileTests {

    // MARK: - Public Methods

    @Test
    func publicBooleanExportSheetModifierCanBeComposed() {
        let request = VideoExportSheetRequest(
            sourceVideoURL: URL(fileURLWithPath: "/tmp/source.mp4")
        )

        let view = Text("Export")
            .videoExportSheet(
                isPresented: .constant(false),
                request: request,
                onExported: { _ in }
            )

        #expect(Mirror(reflecting: view).children.isEmpty == false)
    }

    @Test
    func publicItemExportSheetModifierCanBeComposed() {
        let item = ExportProbeItem(
            id: UUID(),
            sourceVideoURL: URL(fileURLWithPath: "/tmp/source.mp4")
        )

        let view = Text("Export")
            .videoExportSheet(
                item: .constant(Optional(item)),
                request: { item in
                    VideoExportSheetRequest(
                        id: item.id.uuidString,
                        sourceVideoURL: item.sourceVideoURL
                    )
                },
                onExported: { _, _ in }
            )

        #expect(Mirror(reflecting: view).children.isEmpty == false)
    }

}

private struct ExportProbeItem: Identifiable {

    // MARK: - Public Properties

    let id: UUID
    let sourceVideoURL: URL

}
```

- [ ] **Step 2: Run the failing compile tests**

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test \
  -only-testing:VideoEditorKitTests/VideoExportSheetModifierCompileTests
```

Expected: FAIL because `videoExportSheet` does not exist.

- [ ] **Step 3: Implement the modifiers**

Create `Sources/VideoEditorKit/Views/Export/View+VideoExportSheet.swift`:

```swift
import SwiftUI

public extension View {

    // MARK: - Public Methods

    func videoExportSheet(
        isPresented: Binding<Bool>,
        request: VideoExportSheetRequest,
        configuration: VideoEditorConfiguration = .init(),
        onExported: @escaping (ExportedVideo) -> Void
    ) -> some View {
        modifier(
            VideoExportBooleanSheetModifier(
                isPresented: isPresented,
                request: request,
                configuration: configuration,
                onExported: onExported
            )
        )
    }

    func videoExportSheet<Item: Identifiable>(
        item: Binding<Item?>,
        configuration: VideoEditorConfiguration = .init(),
        request: @escaping (Item) -> VideoExportSheetRequest,
        onExported: @escaping (ExportedVideo, Item) -> Void
    ) -> some View {
        modifier(
            VideoExportItemSheetModifier(
                item: item,
                configuration: configuration,
                request: request,
                onExported: onExported
            )
        )
    }

}

private struct VideoExportBooleanSheetModifier: ViewModifier {

    // MARK: - Bindings

    @Binding private var isPresented: Bool

    // MARK: - Private Properties

    private let request: VideoExportSheetRequest
    private let configuration: VideoEditorConfiguration
    private let onExported: (ExportedVideo) -> Void

    // MARK: - Initializer

    init(
        isPresented: Binding<Bool>,
        request: VideoExportSheetRequest,
        configuration: VideoEditorConfiguration,
        onExported: @escaping (ExportedVideo) -> Void
    ) {
        _isPresented = isPresented

        self.request = request
        self.configuration = configuration
        self.onExported = onExported
    }

    // MARK: - Public Methods

    func body(content: Content) -> some View {
        content
            .dynamicSheet(
                isPresented: $isPresented,
                initialHeight: 420
            ) {
                VideoExportSheet(
                    request: request,
                    configuration: configuration,
                    onExported: handleExported
                )
            }
    }

    // MARK: - Private Methods

    private func handleExported(_ exportedVideo: ExportedVideo) {
        isPresented = false
        onExported(exportedVideo)
    }

}

private struct VideoExportItemSheetModifier<Item: Identifiable>: ViewModifier {

    // MARK: - Bindings

    @Binding private var item: Item?

    // MARK: - Private Properties

    private let configuration: VideoEditorConfiguration
    private let request: (Item) -> VideoExportSheetRequest
    private let onExported: (ExportedVideo, Item) -> Void

    // MARK: - Initializer

    init(
        item: Binding<Item?>,
        configuration: VideoEditorConfiguration,
        request: @escaping (Item) -> VideoExportSheetRequest,
        onExported: @escaping (ExportedVideo, Item) -> Void
    ) {
        _item = item

        self.configuration = configuration
        self.request = request
        self.onExported = onExported
    }

    // MARK: - Public Methods

    func body(content: Content) -> some View {
        content
            .dynamicSheet(
                item: $item,
                initialHeight: { _ in 420 }
            ) { item in
                VideoExportSheet(
                    request: request(item),
                    configuration: configuration,
                    onExported: { exportedVideo in
                        handleExported(exportedVideo, item: item)
                    }
                )
            }
    }

    // MARK: - Private Methods

    private func handleExported(
        _ exportedVideo: ExportedVideo,
        item exportedItem: Item
    ) {
        item = nil
        onExported(exportedVideo, exportedItem)
    }

}
```

- [ ] **Step 4: Run the modifier compile tests**

Run the same `xcodebuild ... -only-testing:VideoEditorKitTests/VideoExportSheetModifierCompileTests` command.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VideoEditorKit/Views/Export/View+VideoExportSheet.swift Tests/VideoEditorKitTests/Views/VideoExportSheetModifierCompileTests.swift
git commit -m "feat: expose export sheet view modifier"
```

---

### Task 4: Wire The Example Project List

**Files:**
- Modify: `Example/VideoEditor/Views/RootView/RootView.swift`

- [ ] **Step 1: Update the list share state**

In `RootView`, replace:

```swift
    @State private var sharedVideo: ProjectVideoAction?
```

with:

```swift
    @State private var exportingProject: EditedVideoProject?
    @State private var sharedVideo: ProjectVideoAction?
```

- [ ] **Step 2: Replace the direct share sheet path**

In `RootView.body`, replace the direct `.sheet(item: $sharedVideo)` chain with this modifier followed by the existing share sheet:

```swift
            .videoExportSheet(
                item: $exportingProject,
                request: exportRequest(for:),
                onExported: { exportedVideo, project in
                    sharedVideo = .init(id: project.id, url: exportedVideo.url)
                }
            )
            .sheet(item: $sharedVideo) { videoAction in
                VideoShareSheet(
                    activityItems: [videoAction.url],
                    onCompletion: handleShareCompletion
                )
            }
```

- [ ] **Step 3: Make the share action present the export-quality sheet**

Replace `shareSavedVideo(_:)` with:

```swift
    private func shareSavedVideo(_ project: EditedVideoProject) {
        guard project.hasOriginalVideo else {
            showPersistenceError(ExampleStrings.missingProjectOriginalVideo)
            return
        }

        guard project.editingConfiguration != nil else {
            showPersistenceError(ExampleStrings.missingSavedVideo)
            return
        }

        exportingProject = project
    }
```

- [ ] **Step 4: Add the request builder**

Add this method near `shareSavedVideo(_:)`:

```swift
    private func exportRequest(
        for project: EditedVideoProject
    ) -> VideoExportSheetRequest {
        VideoExportSheetRequest(
            id: project.id.uuidString,
            sourceVideoURL: project.originalVideoURL,
            editingConfiguration: project.editingConfiguration ?? .initial,
            preparedOriginalExportVideo: project.preparedOriginalExportVideo,
            preparedOriginalExportEditingConfiguration: project.editingConfiguration
        )
    }
```

- [ ] **Step 5: Build the example app**

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditor \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Example/VideoEditor/Views/RootView/RootView.swift
git commit -m "feat: use export sheet from saved project list"
```

---

### Task 5: Documentation

**Files:**
- Modify: `README.md`
- Modify: `Docs/FEATURES.md`
- Modify: `Sources/VideoEditorKit/VideoEditorKit.docc/VideoEditorKit.md`

- [ ] **Step 1: Update the README feature/API map**

In `README.md`, add `VideoExportSheetRequest` to the Export API map:

```markdown
- Export: `VideoQuality`, `ExportQualityAvailability`, `VideoExportSheetRequest`, `ExportedVideo`
```

Add this section after `## Sessions`:

````markdown
## External Export Sheet

Use `videoExportSheet(item:request:onExported:)` when a host screen needs the
same quality picker and blocking rules outside the editor, such as sharing from a
saved-project list:

```swift
.videoExportSheet(
    item: $selectedProject,
    configuration: VideoEditorConfiguration(
        exportQualities: ExportQualityAvailability.premiumLocked,
        onBlockedExportQualityTap: { quality in
            presentUpgrade(for: quality)
        }
    ),
    request: { project in
        VideoExportSheetRequest(
            id: project.id.uuidString,
            sourceVideoURL: project.originalVideoURL,
            editingConfiguration: project.editingConfiguration,
            preparedOriginalExportVideo: project.preparedOriginalExportVideo
        )
    },
    onExported: { exportedVideo, project in
        share(exportedVideo.url, for: project)
    }
)
```

The modifier reuses the package export UI, keeps `.original` available, calls the
blocked-quality callback for locked qualities, renders the selected quality, and
returns the exported file through `onExported`.
````

- [ ] **Step 2: Update feature docs**

In `Docs/FEATURES.md`, add this bullet under `Editor Features`:

```markdown
- Present the export-quality sheet outside the editor with `videoExportSheet`.
```

Add this bullet under `Main Public Types`:

```markdown
- `VideoExportSheetRequest`: source and editing payload for external export sheets.
```

- [ ] **Step 3: Update DocC API map**

In `Sources/VideoEditorKit/VideoEditorKit.docc/VideoEditorKit.md`, update the export bullet to include `VideoExportSheetRequest` and add one sentence:

```markdown
Use `videoExportSheet(item:request:onExported:)` to present the package export
quality sheet from host screens outside `VideoEditorView`.
```

- [ ] **Step 4: Commit**

```bash
git add README.md Docs/FEATURES.md Sources/VideoEditorKit/VideoEditorKit.docc/VideoEditorKit.md
git commit -m "docs: document external export sheet modifier"
```

---

### Task 6: Formatting And Full Validation

**Files:**
- Validate all touched Swift files and docs.

- [ ] **Step 1: Format Swift**

Run:

```bash
scripts/format-swift.sh
```

Expected: completes without errors.

- [ ] **Step 2: Run preferred validation**

Run:

```bash
scripts/test-ios.sh
```

Expected: PASS.

- [ ] **Step 3: If full validation is too slow, run targeted package and example tests**

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

Expected: PASS.

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditor \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

Expected: PASS.

- [ ] **Step 4: Commit final formatting changes**

```bash
git status --short
git add Sources/VideoEditorKit Tests/VideoEditorKitTests Example/VideoEditor README.md Docs/FEATURES.md Sources/VideoEditorKit/VideoEditorKit.docc/VideoEditorKit.md
git commit -m "chore: validate external export sheet modifier"
```

---

## Self-Review

Spec coverage:
- External sheet outside the editor: covered by `videoExportSheet(item:request:onExported:)`.
- Same quality UI: reuses `VideoExporterContainerView` and `VideoExporterView`.
- Blocking rules: uses `VideoEditorConfiguration.exportQualities` and `notifyBlockedExportQualityTap(for:)`.
- List share use case: `RootView` opens the export sheet first, then `VideoShareSheet` after export.
- Selected low/medium/high render: delegated to existing `ExporterViewModel` and `VideoEditor.startRender`.
- `.original` remains available: preserved by existing `ExportQualityAvailability` normalization and preparation resolver.

Placeholder scan:
- No implementation step uses unspecified behavior or deferred placeholders.

Type consistency:
- Public modifier overloads use `VideoExportSheetRequest`.
- Public preparation uses `VideoExportPreparationResult`; internal container maps it to `ExporterViewModel.ExportPreparationResult`.
- Example list callback receives `(ExportedVideo, EditedVideoProject)` and shares `exportedVideo.url`.
