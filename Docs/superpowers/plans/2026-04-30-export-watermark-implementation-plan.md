# Export Watermark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional host-configured export watermark to `VideoEditorKit` without affecting preview, manual save, thumbnails, or persisted edit state.

**Architecture:** The public API lives in `VideoEditorConfiguration` because watermarking is host policy, not resumable edit state. The export UI passes a lightweight internal render request into `VideoEditor.startRender`; `VideoEditor` applies the watermark as a final render stage after base/canvas, adjusts, and transcript stages so every export quality, including `.original`, receives the logo.

**Tech Stack:** Swift 6.2, SwiftUI-facing public API, AVFoundation export sessions, Core Animation overlays, Swift Testing, iOS 18.6+.

---

## Non-Negotiable Requirements

- The watermark is optional and removable by passing `nil`.
- The host provides a `UIImage`.
- The exported logo uses exactly `UIImage.size`; no automatic scaling, fitting, or percentage sizing.
- The watermark appears in one corner: top leading, top trailing, bottom leading, or bottom trailing.
- The watermark has fixed padding of 16 render-coordinate pixels from the selected edges.
- The watermark is applied only during explicit export, including `.original`, `.low`, `.medium`, and `.high`.
- Manual save output, saved thumbnails, preview, and `VideoEditingConfiguration` remain watermark-free.
- Keep using `import SwiftUI`; do not add direct `import UIKit`.
- Use Build iOS Apps guidance for SwiftUI API wiring and validation.

## File Map

- Modify `Sources/VideoEditorKit/API/VideoEditorPublicTypes.swift`
  - Add `VideoWatermarkPosition`.
  - Add `VideoWatermarkConfiguration`.
  - Add `VideoEditorConfiguration.watermark`.
  - Convert the file import from `Foundation` to `SwiftUI` so `UIImage` is available through the project-approved UI-facing import.
- Create `Sources/VideoEditorKit/Export/VideoWatermarkLayout.swift`
  - Pure geometry helper for the four corner frames.
- Create `Sources/VideoEditorKit/Internal/Export/VideoWatermarkRenderRequest.swift`
  - Internal sendable render payload extracted from the public `UIImage`.
- Modify `Sources/VideoEditorKit/Views/Editor/VideoEditorView.swift`
  - Pass `configuration.watermark` into export UI.
  - Disable prepared/original fast paths when watermark exists.
- Modify `Sources/VideoEditorKit/Views/Export/VideoExportSheet.swift`
  - Pass `configuration.watermark` into export UI.
  - Make default preparation resolver aware of watermark.
- Modify `Sources/VideoEditorKit/Views/Export/VideoExporterContainerView.swift`
  - Accept optional public watermark configuration and create the internal render request for `ExporterViewModel`.
- Modify `Sources/VideoEditorKit/Internal/ViewModels/ExporterViewModel.swift`
  - Carry optional `VideoWatermarkRenderRequest`.
  - Forward it to the injected renderer and default `VideoEditor.startRender`.
- Modify `Sources/VideoEditorKit/Internal/Models/Enums/VideoEditor.swift`
  - Add a watermark render stage.
  - Add final `applyWatermarkOperation`.
  - Add `createWatermarkAnimationTool`.
- Modify tests:
  - `Tests/VideoEditorKitTests/VideoEditorPublicTypesTests.swift`
  - `Tests/VideoEditorKitTests/Models/VideoEditorTests.swift`
  - `Tests/VideoEditorKitTests/Views/VideoExportSheetRequestTests.swift`
  - `Tests/VideoEditorKitTests/ViewModels/ExporterViewModelTests.swift`
- Modify docs:
  - `README.md`
  - `Docs/FEATURES.md`
  - `Docs/ARCHITECTURE.md`

---

### Task 1: Add Public Watermark API

**Files:**
- Modify: `Sources/VideoEditorKit/API/VideoEditorPublicTypes.swift`
- Modify: `Tests/VideoEditorKitTests/VideoEditorPublicTypesTests.swift`

- [ ] **Step 1: Write public API tests**

Add these tests to `VideoEditorPublicTypesTests`:

```swift
@Test
func configurationDefaultsToNoWatermark() {
    let configuration = VideoEditorConfiguration()

    #expect(configuration.watermark == nil)
}

@Test
func configurationStoresOptionalWatermarkPolicy() {
    let image = TestFixtures.makeSolidImage(
        size: CGSize(width: 40, height: 20),
        scale: 1
    )
    let watermark = VideoWatermarkConfiguration(
        image: image,
        position: .bottomTrailing
    )
    let configuration = VideoEditorConfiguration(
        watermark: watermark
    )

    #expect(configuration.watermark?.image.size == CGSize(width: 40, height: 20))
    #expect(configuration.watermark?.position == .bottomTrailing)
}

@Test
func videoEditorViewNamespaceExposesWatermarkConfigurationTypes() {
    let image = TestFixtures.makeSolidImage(
        size: CGSize(width: 24, height: 12),
        scale: 1
    )
    let watermark = VideoEditorView.WatermarkConfiguration(
        image: image,
        position: .topLeading
    )
    let configuration = VideoEditorView.Configuration(
        watermark: watermark
    )

    #expect(configuration.watermark?.image.size == CGSize(width: 24, height: 12))
    #expect(configuration.watermark?.position == .topLeading)
}
```

- [ ] **Step 2: Run the targeted tests and confirm they fail**

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:VideoEditorKitTests/VideoEditorPublicTypesTests \
  test
```

Expected: FAIL because `VideoWatermarkConfiguration`, `VideoWatermarkPosition`, and `VideoEditorConfiguration.watermark` do not exist.

- [ ] **Step 3: Add the public types**

In `VideoEditorPublicTypes.swift`, replace:

```swift
import Foundation
```

with:

```swift
import SwiftUI
```

Add these public types before `VideoEditorConfiguration`:

```swift
/// Supported corners for an export-only watermark.
public enum VideoWatermarkPosition: Equatable, Sendable {

    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

}

/// Host-facing configuration for an optional export-only watermark.
public struct VideoWatermarkConfiguration {

    // MARK: - Public Properties

    /// Image rendered into exported videos at exactly `image.size`.
    public let image: UIImage
    /// Corner where the image is rendered with fixed export padding.
    public let position: VideoWatermarkPosition

    // MARK: - Initializer

    public init(
        image: UIImage,
        position: VideoWatermarkPosition
    ) {
        self.image = image
        self.position = position
    }

}
```

In `VideoEditorConfiguration`, add the public property after `exportQualities`:

```swift
/// Optional export-only watermark applied to rendered export outputs.
public let watermark: VideoWatermarkConfiguration?
```

Update the initializer signature:

```swift
public init(
    tools: [ToolAvailability] = ToolAvailability.enabled(ToolEnum.all),
    exportQualities: [ExportQualityAvailability] = ExportQualityAvailability.allEnabled,
    watermark: VideoWatermarkConfiguration? = nil,
    transcription: TranscriptionConfiguration? = nil,
    maximumVideoDuration: TimeInterval? = nil,
    onBlockedToolTap: ((ToolEnum) -> Void)? = nil,
    onBlockedExportQualityTap: ((VideoQuality) -> Void)? = nil
)
```

Assign it in the initializer:

```swift
self.watermark = watermark
```

In `VideoEditorView`, add typealiases in the public properties section:

```swift
/// Export-only watermark configuration exposed through the editor namespace.
public typealias WatermarkConfiguration = VideoWatermarkConfiguration
/// Export-only watermark corner exposed through the editor namespace.
public typealias WatermarkPosition = VideoWatermarkPosition
```

- [ ] **Step 4: Run the targeted tests and confirm they pass**

Run the same `xcodebuild ... -only-testing:VideoEditorKitTests/VideoEditorPublicTypesTests test` command.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VideoEditorKit/API/VideoEditorPublicTypes.swift Sources/VideoEditorKit/Views/Editor/VideoEditorView.swift Tests/VideoEditorKitTests/VideoEditorPublicTypesTests.swift
git commit -m "feat: add export watermark configuration API"
```

---

### Task 2: Add Pure Watermark Layout

**Files:**
- Create: `Sources/VideoEditorKit/Export/VideoWatermarkLayout.swift`
- Modify: `Tests/VideoEditorKitTests/Models/VideoEditorTests.swift`

- [ ] **Step 1: Write frame calculation tests**

Add these tests to `VideoEditorTests`:

```swift
@Test
func watermarkLayoutUsesExactImageSizeAndTopLeadingPadding() {
    let frame = VideoWatermarkLayout.frame(
        renderSize: CGSize(width: 1920, height: 1080),
        imageSize: CGSize(width: 120, height: 48),
        position: .topLeading
    )

    #expect(frame == CGRect(x: 16, y: 16, width: 120, height: 48))
}

@Test
func watermarkLayoutUsesTopTrailingPadding() {
    let frame = VideoWatermarkLayout.frame(
        renderSize: CGSize(width: 1920, height: 1080),
        imageSize: CGSize(width: 120, height: 48),
        position: .topTrailing
    )

    #expect(frame == CGRect(x: 1784, y: 16, width: 120, height: 48))
}

@Test
func watermarkLayoutUsesBottomLeadingPadding() {
    let frame = VideoWatermarkLayout.frame(
        renderSize: CGSize(width: 1920, height: 1080),
        imageSize: CGSize(width: 120, height: 48),
        position: .bottomLeading
    )

    #expect(frame == CGRect(x: 16, y: 1016, width: 120, height: 48))
}

@Test
func watermarkLayoutUsesBottomTrailingPadding() {
    let frame = VideoWatermarkLayout.frame(
        renderSize: CGSize(width: 1920, height: 1080),
        imageSize: CGSize(width: 120, height: 48),
        position: .bottomTrailing
    )

    #expect(frame == CGRect(x: 1784, y: 1016, width: 120, height: 48))
}
```

- [ ] **Step 2: Run the targeted tests and confirm they fail**

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:VideoEditorKitTests/VideoEditorTests \
  test
```

Expected: FAIL because `VideoWatermarkLayout` does not exist.

- [ ] **Step 3: Add the layout helper**

Create `Sources/VideoEditorKit/Export/VideoWatermarkLayout.swift`:

```swift
import CoreGraphics

public enum VideoWatermarkLayout {

    // MARK: - Public Properties

    public static let padding: CGFloat = 16

    // MARK: - Public Methods

    public static func frame(
        renderSize: CGSize,
        imageSize: CGSize,
        position: VideoWatermarkPosition
    ) -> CGRect {
        let width = max(imageSize.width, 0)
        let height = max(imageSize.height, 0)
        let maxOriginX = max(renderSize.width - width - padding, padding)
        let maxOriginY = max(renderSize.height - height - padding, padding)

        let origin: CGPoint =
            switch position {
            case .topLeading:
                CGPoint(x: padding, y: padding)
            case .topTrailing:
                CGPoint(x: maxOriginX, y: padding)
            case .bottomLeading:
                CGPoint(x: padding, y: maxOriginY)
            case .bottomTrailing:
                CGPoint(x: maxOriginX, y: maxOriginY)
            }

        return CGRect(
            origin: origin,
            size: CGSize(width: width, height: height)
        )
    }

}
```

- [ ] **Step 4: Run the targeted tests and confirm they pass**

Run the same `xcodebuild ... -only-testing:VideoEditorKitTests/VideoEditorTests test` command.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VideoEditorKit/Export/VideoWatermarkLayout.swift Tests/VideoEditorKitTests/Models/VideoEditorTests.swift
git commit -m "feat: add watermark layout resolver"
```

---

### Task 3: Disable Original Export Shortcuts When Watermark Exists

**Files:**
- Modify: `Sources/VideoEditorKit/Views/Export/VideoExportSheet.swift`
- Modify: `Sources/VideoEditorKit/Views/Editor/VideoEditorView.swift`
- Modify: `Tests/VideoEditorKitTests/Views/VideoExportSheetRequestTests.swift`

- [ ] **Step 1: Write default export-sheet resolver tests**

Add these tests to `VideoExportSheetRequestTests`:

```swift
@Test
func defaultPreparationRendersPreparedOriginalWhenWatermarkExists() {
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
        loadedOriginalVideo: nil,
        hasWatermark: true
    )

    #expect(result == .render)
}

@Test
func defaultPreparationRendersLoadedOriginalWhenWatermarkExists() {
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
        loadedOriginalVideo: loadedOriginal,
        hasWatermark: true
    )

    #expect(result == .render)
}
```

Update existing calls in this test file by adding `hasWatermark: false`.

- [ ] **Step 2: Run the targeted tests and confirm they fail**

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:VideoEditorKitTests/VideoExportSheetRequestTests \
  test
```

Expected: FAIL because `preparationResult(...hasWatermark:)` does not exist.

- [ ] **Step 3: Update preparation resolver**

In `VideoExportSheet.resolvedPrepareForExport`, pass:

```swift
hasWatermark: configuration.watermark != nil
```

Change the resolver signature:

```swift
static func preparationResult(
    selectedQuality: VideoQuality,
    request: VideoExportSheetRequest,
    loadedOriginalVideo: ExportedVideo?,
    hasWatermark: Bool = false
) -> VideoExportPreparationResult {
    guard hasWatermark == false else {
        return .render
    }

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
```

In `VideoEditorView.prepareCurrentExport`, pass watermark awareness into `Self.exportPreparationResult`. If the current helper does not accept this flag, add `hasWatermark: Bool` to that static helper and return `.render` before prepared video reuse when `hasWatermark == true`.

Call it with:

```swift
hasWatermark: configuration.watermark != nil
```

- [ ] **Step 4: Run the targeted tests and confirm they pass**

Run the same `xcodebuild ... -only-testing:VideoEditorKitTests/VideoExportSheetRequestTests test` command.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VideoEditorKit/Views/Export/VideoExportSheet.swift Sources/VideoEditorKit/Views/Editor/VideoEditorView.swift Tests/VideoEditorKitTests/Views/VideoExportSheetRequestTests.swift
git commit -m "fix: render original exports when watermark is enabled"
```

---

### Task 4: Propagate Watermark Into Export Rendering

**Files:**
- Create: `Sources/VideoEditorKit/Internal/Export/VideoWatermarkRenderRequest.swift`
- Modify: `Sources/VideoEditorKit/Views/Export/VideoExporterContainerView.swift`
- Modify: `Sources/VideoEditorKit/Internal/ViewModels/ExporterViewModel.swift`
- Modify: `Sources/VideoEditorKit/Views/Editor/VideoEditorView.swift`
- Modify: `Sources/VideoEditorKit/Views/Export/VideoExportSheet.swift`
- Modify: `Tests/VideoEditorKitTests/ViewModels/ExporterViewModelTests.swift`

- [ ] **Step 1: Write ExporterViewModel forwarding test**

Change `ExporterViewModel.RenderVideo` test closures to accept the new fifth argument after `quality`. Then add:

```swift
@Test
func exportPassesWatermarkToRenderer() async {
    let expectedURL = URL(fileURLWithPath: "/tmp/watermarked-export.mp4")
    let expectedVideo = ExportedVideo(
        expectedURL,
        width: 1280,
        height: 720,
        duration: 8,
        fileSize: 256
    )
    let image = TestFixtures.makeSolidImage(
        size: CGSize(width: 32, height: 18),
        scale: 1
    )
    let watermark = VideoWatermarkConfiguration(
        image: image,
        position: .topTrailing
    )
    let tracker = ExportWatermarkTracker()
    let viewModel = ExporterViewModel(
        Video.mock,
        watermark: watermark,
        renderVideo: { _, _, _, watermark, _ in
            await tracker.record(watermark)
            return expectedURL
        },
        loadExportedVideo: { _ in expectedVideo }
    )

    viewModel.exportVideo { exportedVideo in
        Task {
            await tracker.recordExportedVideo(exportedVideo)
        }
    }

    await tracker.waitUntilExportedVideoIsRecorded()

    #expect(await tracker.imageSizes == [CGSize(width: 32, height: 18)])
    #expect(await tracker.positions == [.topTrailing])
    #expect(await tracker.exportedVideo == expectedVideo)
}
```

Add the actor to the bottom of the test file:

```swift
private actor ExportWatermarkTracker {

    // MARK: - Public Properties

    private(set) var imageSizes = [CGSize]()
    private(set) var positions = [VideoWatermarkPosition]()
    private(set) var exportedVideo: ExportedVideo?

    // MARK: - Public Methods

    func record(_ watermark: VideoWatermarkRenderRequest?) {
        guard let watermark else { return }
        imageSizes.append(watermark.imageSize)
        positions.append(watermark.position)
    }

    func recordExportedVideo(_ video: ExportedVideo) {
        exportedVideo = video
    }

    func waitUntilExportedVideoIsRecorded() async {
        for _ in 0..<50 where exportedVideo == nil {
            await Task.yield()
        }
    }

}
```

- [ ] **Step 2: Run the targeted tests and confirm they fail**

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:VideoEditorKitTests/ExporterViewModelTests \
  test
```

Expected: FAIL because `VideoWatermarkRenderRequest`, the new initializer argument, and the new render closure signature do not exist.

- [ ] **Step 3: Add internal render request**

Create `Sources/VideoEditorKit/Internal/Export/VideoWatermarkRenderRequest.swift`:

```swift
import CoreGraphics
import SwiftUI

struct VideoWatermarkRenderRequest: @unchecked Sendable {

    // MARK: - Public Properties

    let image: CGImage
    let imageSize: CGSize
    let imageScale: CGFloat
    let position: VideoWatermarkPosition

    // MARK: - Initializer

    @MainActor
    init?(_ configuration: VideoWatermarkConfiguration?) {
        guard let configuration else { return nil }
        guard let cgImage = configuration.image.cgImage else { return nil }

        image = cgImage
        imageSize = configuration.image.size
        imageScale = max(configuration.image.scale, 1)
        position = configuration.position
    }

}
```

- [ ] **Step 4: Update exporter model signatures**

In `ExporterViewModel`, add:

```swift
let watermark: VideoWatermarkRenderRequest?
```

Change `RenderVideo` to:

```swift
typealias RenderVideo =
    @Sendable (
        _ video: Video,
        _ editingConfiguration: VideoEditingConfiguration,
        _ quality: VideoQuality,
        _ watermark: VideoWatermarkRenderRequest?,
        _ onProgress: VideoEditor.ProgressHandler?
    ) async throws -> URL
```

Change the default render closure:

```swift
renderVideo: @escaping RenderVideo = { video, editingConfiguration, quality, watermark, onProgress in
    try await VideoEditor.startRender(
        video: video,
        editingConfiguration: editingConfiguration,
        videoQuality: quality,
        watermark: watermark,
        onProgress: onProgress
    )
}
```

Update the initializer:

```swift
init(
    _ video: Video,
    editingConfiguration: VideoEditingConfiguration = .initial,
    exportQualities: [ExportQualityAvailability] = ExportQualityAvailability.allEnabled,
    watermark: VideoWatermarkConfiguration? = nil,
    renderVideo: @escaping RenderVideo = { video, editingConfiguration, quality, watermark, onProgress in
        try await VideoEditor.startRender(
            video: video,
            editingConfiguration: editingConfiguration,
            videoQuality: quality,
            watermark: watermark,
            onProgress: onProgress
        )
    },
    loadExportedVideo: @escaping @Sendable (URL) async -> ExportedVideo = { url in
        await ExportedVideo.load(from: url)
    },
    lifecycleCoordinator: ExportLifecycleCoordinator = .init(),
    lifecycleNow: @escaping @Sendable () -> Date = Date.init
)
```

Inside the initializer:

```swift
self.watermark = VideoWatermarkRenderRequest(watermark)
```

Change the renderer call in `export(runID:selectedQuality:)`:

```swift
let url = try await renderVideo(video, editingConfiguration, selectedQuality, watermark) { [weak self] progress in
```

- [ ] **Step 5: Pass watermark from views**

In `VideoExporterContainerView`, add:

```swift
private let watermark: VideoWatermarkConfiguration?
```

Add `watermark: VideoWatermarkConfiguration? = nil` to both initializers. Pass it into the `ExporterViewModel` initializer:

```swift
_viewModel = State(
    initialValue: ExporterViewModel(
        video,
        editingConfiguration: editingConfiguration,
        exportQualities: exportQualities,
        watermark: watermark
    )
)
```

In the delegating initializer, forward `watermark: watermark`.

In `VideoEditorView.exportSheetContent`, pass:

```swift
watermark: configuration.watermark,
```

In `VideoExportSheet.body`, pass:

```swift
watermark: configuration.watermark,
```

- [ ] **Step 6: Run the targeted tests and confirm they pass**

Run the same `xcodebuild ... -only-testing:VideoEditorKitTests/ExporterViewModelTests test` command.

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/VideoEditorKit/Internal/Export/VideoWatermarkRenderRequest.swift Sources/VideoEditorKit/Views/Export/VideoExporterContainerView.swift Sources/VideoEditorKit/Internal/ViewModels/ExporterViewModel.swift Sources/VideoEditorKit/Views/Editor/VideoEditorView.swift Sources/VideoEditorKit/Views/Export/VideoExportSheet.swift Tests/VideoEditorKitTests/ViewModels/ExporterViewModelTests.swift
git commit -m "feat: pass watermark policy into export renderer"
```

---

### Task 5: Apply Watermark As Final Export Stage

**Files:**
- Modify: `Sources/VideoEditorKit/Internal/Models/Enums/VideoEditor.swift`
- Modify: `Tests/VideoEditorKitTests/Models/VideoEditorTests.swift`

- [ ] **Step 1: Write render behavior tests**

Add this helper to `VideoEditorTests` if no shared pixel helper exists in test support:

```swift
private struct RenderedPixel {

    // MARK: - Public Properties

    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8

    var isMostlyBlue: Bool {
        blue > 160 && red < 120 && green < 160 && alpha > 180
    }

}

private func renderedPixel(
    in image: CGImage,
    x: Int,
    y: Int
) -> RenderedPixel? {
    guard x >= 0, y >= 0, x < image.width, y < image.height else { return nil }
    guard let dataProviderData = image.dataProvider?.data else { return nil }
    guard let data = CFDataGetBytePtr(dataProviderData) else { return nil }

    let bytesPerPixel = max(image.bitsPerPixel / 8, 1)
    let offset = (y * image.bytesPerRow) + (x * bytesPerPixel)
    guard offset + 3 < CFDataGetLength(dataProviderData) else { return nil }

    return RenderedPixel(
        red: data[offset],
        green: data[offset + 1],
        blue: data[offset + 2],
        alpha: data[offset + 3]
    )
}
```

Add this async test:

```swift
@Test
func exportRenderAppliesWatermarkAtTopLeadingPadding() async throws {
    let sourceURL = try await TestFixtures.createTemporaryVideo(
        size: CGSize(width: 96, height: 64),
        frameCount: 6,
        framesPerSecond: 30,
        color: .systemRed
    )
    defer { FileManager.default.removeIfExists(for: sourceURL) }

    let video = await Video.load(from: sourceURL)
    let watermarkImage = TestFixtures.makeSolidImage(
        size: CGSize(width: 12, height: 10),
        color: .systemBlue,
        scale: 1
    )
    let watermark = await VideoWatermarkRenderRequest(
        VideoWatermarkConfiguration(
            image: watermarkImage,
            position: .topLeading
        )
    )

    let exportedURL = try await VideoEditor.startRender(
        video: video,
        editingConfiguration: .initial,
        videoQuality: .original,
        watermark: watermark
    )
    defer { FileManager.default.removeIfExists(for: exportedURL) }

    let asset = AVURLAsset(url: exportedURL)
    let renderedImage = try #require(
        await asset.generateImage(
            at: 0,
            maximumSize: CGSize(width: 96, height: 64),
            requiresExactFrame: true
        )?.cgImage
    )

    #expect(renderedPixel(in: renderedImage, x: 20, y: 20)?.isMostlyBlue == true)
}
```

- [ ] **Step 2: Run the targeted tests and confirm they fail**

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:VideoEditorKitTests/VideoEditorTests \
  test
```

Expected: FAIL because `VideoEditor.startRender(...watermark:)` and the render stage do not exist.

- [ ] **Step 3: Add watermark parameters to VideoEditor.startRender**

Change the public internal convenience:

```swift
static func startRender(
    video: Video,
    editingConfiguration: VideoEditingConfiguration = .initial,
    videoQuality: VideoQuality,
    watermark: VideoWatermarkRenderRequest? = nil,
    onProgress: ProgressHandler? = nil
) async throws -> URL {
    try await startRender(
        video: video,
        editingConfiguration: editingConfiguration,
        renderIntent: .export(videoQuality),
        watermark: watermark,
        onProgress: onProgress
    )
}
```

Change the render-intent overload:

```swift
static func startRender(
    video: Video,
    editingConfiguration: VideoEditingConfiguration = .initial,
    renderIntent: VideoRenderIntent,
    watermark: VideoWatermarkRenderRequest? = nil,
    onProgress: ProgressHandler? = nil
) async throws -> URL
```

Do not pass watermark from `VideoEditorManualSaveRenderer`; its existing call remains watermark-free because the new parameter defaults to `nil`.

- [ ] **Step 4: Add watermark stage plumbing**

Add `.watermark`:

```swift
enum RenderStage: Equatable {
    case base
    case adjusts
    case transcript
    case crop
    case watermark
}
```

Change `resolvedRenderStages` signature:

```swift
static func resolvedRenderStages(
    usesAdjustsStage: Bool,
    usesTranscriptStage: Bool,
    usesCropStage: Bool,
    usesWatermarkStage: Bool
) -> [RenderStage]
```

Append:

```swift
if usesWatermarkStage {
    stages.append(.watermark)
}
```

In `startRender`, define:

```swift
let usesWatermarkStage = watermark != nil
```

Pass it to `resolvedRenderStages`.

After `applyTranscriptOperation`, add:

```swift
let watermarkedURL = try await applyWatermarkOperation(
    watermark,
    fromUrl: transcribedURL,
    exportProfile: exportProfile,
    progressRange: progressRange(
        for: .watermark,
        activeStages: renderStages
    ),
    onProgress: onProgress
)
advanceIntermediateOutput(
    from: transcribedURL,
    to: watermarkedURL,
    trackedURLs: &intermediateOutputURLs
)
cleanupIntermediateOutputs(
    intermediateOutputURLs,
    excluding: watermarkedURL
)
return watermarkedURL
```

- [ ] **Step 5: Add final watermark operation**

Add this private method near `applyTranscriptOperation`:

```swift
private static func applyWatermarkOperation(
    _ watermark: VideoWatermarkRenderRequest?,
    fromUrl: URL,
    exportProfile: ExportProfile,
    progressRange: ClosedRange<Double>,
    onProgress: ProgressHandler?
) async throws -> URL {
    guard let watermark else {
        await reportProgress(progressRange.upperBound, via: onProgress)
        return fromUrl
    }

    let asset = AVURLAsset(url: fromUrl)
    guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
        throw ExporterError.unknow
    }

    let naturalSize = try await videoTrack.load(.naturalSize)
    let preferredTransform = try await videoTrack.load(.preferredTransform)
    let trackTimeRange = try await videoTrack.load(.timeRange)
    let presentationSize = resolvedPresentationSize(
        naturalSize: naturalSize,
        preferredTransform: preferredTransform
    )
    let instruction = videoCompositionInstructionForTrackWithSizeAndTime(
        preferredTransform: preferredTransform,
        naturalSize: naturalSize,
        presentationSize: presentationSize,
        renderSize: presentationSize,
        track: videoTrack,
        isMirror: false
    )
    let videoInstruction = AVMutableVideoCompositionInstruction()
    videoInstruction.layerInstructions = [instruction]
    videoInstruction.timeRange = trackTimeRange

    let videoComposition = AVMutableVideoComposition()
    videoComposition.animationTool = createWatermarkAnimationTool(
        watermark,
        renderSize: presentationSize
    )
    videoComposition.frameDuration = exportProfile.frameDuration
    videoComposition.instructions = [videoInstruction]
    videoComposition.renderSize = presentationSize

    let outputURL = createTempPath()

    guard
        let session = AVAssetExportSession(
            asset: asset,
            presetName: resolvedExportPresetName(
                for: exportProfile,
                appliesVideoComposition: true
            )
        )
    else {
        assertionFailure("Unable to create watermark export session.")
        throw ExporterError.cannotCreateExportSession
    }

    session.videoComposition = videoComposition

    try await export(
        session,
        to: outputURL,
        as: .mp4,
        progressRange: progressRange,
        onProgress: onProgress
    )

    return outputURL
}
```

Add this helper near `createAnimationTool`:

```swift
private static func createWatermarkAnimationTool(
    _ watermark: VideoWatermarkRenderRequest,
    renderSize: CGSize
) -> AVVideoCompositionCoreAnimationTool {
    let bounds = CGRect(origin: .zero, size: renderSize)

    let videoLayer = CALayer()
    videoLayer.frame = bounds

    let outputLayer = CALayer()
    outputLayer.frame = bounds
    outputLayer.isGeometryFlipped = true
    outputLayer.masksToBounds = true
    outputLayer.addSublayer(videoLayer)

    let watermarkLayer = CALayer()
    watermarkLayer.frame = VideoWatermarkLayout.frame(
        renderSize: renderSize,
        imageSize: watermark.imageSize,
        position: watermark.position
    )
    watermarkLayer.contents = watermark.image
    watermarkLayer.contentsGravity = .resize
    watermarkLayer.contentsScale = watermark.imageScale
    outputLayer.addSublayer(watermarkLayer)

    return AVVideoCompositionCoreAnimationTool(
        postProcessingAsVideoLayer: videoLayer,
        in: outputLayer
    )
}
```

- [ ] **Step 6: Run targeted render tests and confirm they pass**

Run the same `xcodebuild ... -only-testing:VideoEditorKitTests/VideoEditorTests test` command.

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/VideoEditorKit/Internal/Models/Enums/VideoEditor.swift Tests/VideoEditorKitTests/Models/VideoEditorTests.swift
git commit -m "feat: render export watermark overlay"
```

---

### Task 6: Update Public Docs

**Files:**
- Modify: `README.md`
- Modify: `Docs/FEATURES.md`
- Modify: `Docs/ARCHITECTURE.md`

- [ ] **Step 1: Update README usage**

Add a short usage snippet near the export configuration section:

```swift
let logoImage = UIImage(named: "Logo")
let configuration = VideoEditorConfiguration(
    watermark: logoImage.map {
        VideoWatermarkConfiguration(
            image: $0,
            position: .bottomTrailing
        )
    }
)
```

Text to include:

```markdown
Watermarks are export-only. They are not shown in preview, are not included in
manual saves, and are not persisted in `VideoEditingConfiguration`. Pass
`watermark: nil` to disable watermarking, such as for paid plans.
```

- [ ] **Step 2: Update feature map**

In `Docs/FEATURES.md`, add:

```markdown
- Optionally apply a host-configured image watermark during export.
```

In the export/resources section, add:

```markdown
- Watermark configuration: host runtime policy in `VideoEditorConfiguration`;
  export-only and not part of saved edit state.
```

- [ ] **Step 3: Update architecture boundaries**

In `Docs/ARCHITECTURE.md`, add an export note:

```markdown
Watermarks are applied as a final export render stage. They do not alter preview,
manual save, saved thumbnails, or `VideoEditingConfiguration`.
```

- [ ] **Step 4: Commit**

```bash
git add README.md Docs/FEATURES.md Docs/ARCHITECTURE.md
git commit -m "docs: describe export watermark behavior"
```

---

### Task 7: Format And Validate

**Files:**
- Validate all changed Swift and docs files.

- [ ] **Step 1: Format Swift**

Run:

```bash
scripts/format-swift.sh
```

Expected: completes without errors.

- [ ] **Step 2: Run targeted package tests**

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:VideoEditorKitTests/VideoEditorPublicTypesTests \
  -only-testing:VideoEditorKitTests/VideoEditorTests \
  -only-testing:VideoEditorKitTests/VideoExportSheetRequestTests \
  -only-testing:VideoEditorKitTests/ExporterViewModelTests \
  test
```

Expected: PASS.

- [ ] **Step 3: Run full preferred validation**

Run:

```bash
scripts/test-ios.sh
```

Expected: PASS.

- [ ] **Step 4: Commit any formatting-only changes**

If `scripts/format-swift.sh` changed files after the feature commits, commit them:

```bash
git add Sources Tests README.md Docs
git commit -m "style: format export watermark changes"
```

If formatting did not change files, skip this commit and leave the worktree clean.

---

## Self-Review

- Spec coverage: the tasks cover optional host configuration, exact `UIImage.size`, four corner positions, padding 16, export-only behavior, `.original` fast-path bypass, render integration, docs, and validation.
- Persistence boundary: no task adds watermark data to `VideoEditingConfiguration`, `SavedVideo`, project persistence, or manual save.
- Preview boundary: no task adds watermark to player or canvas preview.
- Type consistency: public API uses `VideoWatermarkConfiguration`; render path uses internal `VideoWatermarkRenderRequest`; layout uses `VideoWatermarkLayout`.
- Build iOS Apps usage: the plan follows SwiftUI-facing public API conventions, explicit initializer injection, local state ownership, and the project validation commands.
