# Pinch Pan Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow the video preview to move while the user is actively pinching, using the pinch centroid movement as pan input.

**Architecture:** Keep `VideoCanvasEditorState.interactiveTransform(...)` as the single transform path for combined pan and zoom. Replace the SwiftUI-only canvas gesture in `VideoCanvasPreviewView` with an internal UIKit-backed gesture bridge outside `Views/`, because `MagnifyGesture.Value` exposes `startLocation` but not the current pinch location. The bridge reports one-finger pan and two-finger pinch updates into the existing `InteractionState`.

**Tech Stack:** SwiftUI, UIKit gesture recognizers isolated under `Sources/VideoEditorKit/Internal/Gestures`, Swift Testing, iOS 18.6+.

---

## Files

- Create: `Sources/VideoEditorKit/Internal/Gestures/VideoCanvasInteractionGestureView.swift`
- Modify: `Sources/VideoEditorKit/Views/Canvas/VideoCanvasPreviewView.swift`
- Modify: `Tests/VideoEditorKitTests/VideoCanvasMappingActorTests.swift`
- Create: `Tests/VideoEditorKitTests/VideoCanvasPinchPanGesturePolicyTests.swift`

## Current Behavior

- `VideoCanvasPreviewView.interactiveGesture(layout:)` combines SwiftUI `DragGesture` and `MagnifyGesture`.
- `InteractionState.resolvedTransform(...)` already calls `editorState.interactiveTransform(...)`, which combines `translation`, `magnification`, and `anchor`.
- The missing piece is not mapping math. The missing piece is input data: SwiftUI `MagnifyGesture.Value` has `startLocation`, but not the current pinch centroid, so a moving two-finger pinch cannot reliably update `translation`.

## Desired Behavior

- One-finger drag still pans the video.
- Two-finger pinch still zooms around the pinch start point.
- While pinching, moving both fingers together also pans the video by `currentPinchCentroid - startPinchCentroid`.
- Gesture end still commits one `editorState.transform`, calls `onSnapshotChange`, and calls `onInteractionEnded`.
- Double tap reset behavior stays unchanged.
- Rotation remains explicit; pinch must not rotate the canvas.

---

### Task 1: Characterize Combined Transform Math

**Files:**
- Modify: `Tests/VideoEditorKitTests/VideoCanvasMappingActorTests.swift`

- [ ] **Step 1: Add a focused transform test**

Add this test near the existing `interactiveTransformKeepsTheCanvasCoveredWhileIgnoringGestureRotation()` test:

```swift
    @Test
    func interactiveTransformAppliesPinchCentroidTranslationAfterAnchoredZoom() {
        let actor = VideoCanvasMappingActor()
        let baseline = VideoCanvasTransform(
            normalizedOffset: .zero,
            zoom: 1,
            rotationRadians: 0
        )
        let combined = actor.interactiveTransform(
            from: baseline,
            translation: CGSize(width: 45, height: -30),
            magnification: 1.5,
            anchor: CGPoint(x: 150, y: 150),
            previewCanvasSize: CGSize(width: 300, height: 300),
            source: squareSource,
            preset: .custom(width: 1080, height: 1080),
            freeCanvasSize: squareCanvasSize
        )

        #expect(combined.zoom >= 1.5)
        #expect(combined.normalizedOffset.x > 0.1)
        #expect(combined.normalizedOffset.y < -0.05)
        #expect(abs(combined.rotationRadians) < 0.0001)
        assertCanvasIsCovered(
            actor: actor,
            source: squareSource,
            snapshot: VideoCanvasSnapshot(
                preset: .custom(width: 1080, height: 1080),
                freeCanvasSize: squareCanvasSize,
                transform: combined,
                showsSafeAreaOverlay: false
            )
        )
    }
```

- [ ] **Step 2: Run targeted package tests and verify the characterization passes**

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:VideoEditorKitTests/VideoCanvasMappingActorTests \
  test
```

Expected: PASS. If this fails, inspect `VideoCanvasMappingActor.interactiveTransform(...)` before touching gestures, because the mapping layer would not be ready for pinch-pan input.

- [ ] **Step 3: Commit the characterization**

Run:

```bash
git add Tests/VideoEditorKitTests/VideoCanvasMappingActorTests.swift
git commit -m "test: characterize pinch pan canvas transform"
```

---

### Task 2: Add A Testable Pinch Translation Policy

**Files:**
- Create: `Tests/VideoEditorKitTests/VideoCanvasPinchPanGesturePolicyTests.swift`
- Create: `Sources/VideoEditorKit/Internal/Gestures/VideoCanvasInteractionGestureView.swift`

- [ ] **Step 1: Write the failing policy tests**

Create `Tests/VideoEditorKitTests/VideoCanvasPinchPanGesturePolicyTests.swift`:

```swift
import CoreGraphics
import Testing

@testable import VideoEditorKit

@Suite("VideoCanvasPinchPanGesturePolicyTests")
struct VideoCanvasPinchPanGesturePolicyTests {

    // MARK: - Public Methods

    @Test
    func pinchTranslationUsesCurrentCentroidRelativeToStartCentroid() {
        let translation = VideoCanvasPinchPanGesturePolicy.translation(
            from: CGPoint(x: 120, y: 180),
            to: CGPoint(x: 148, y: 153)
        )

        #expect(abs(translation.width - 28) < 0.0001)
        #expect(abs(translation.height + 27) < 0.0001)
    }

    @Test
    func pinchTranslationIgnoresNonFiniteCoordinates() {
        let translation = VideoCanvasPinchPanGesturePolicy.translation(
            from: CGPoint(x: .nan, y: 180),
            to: CGPoint(x: 148, y: .infinity)
        )

        #expect(translation == .zero)
    }
}
```

- [ ] **Step 2: Add the minimal policy implementation**

Create `Sources/VideoEditorKit/Internal/Gestures/VideoCanvasInteractionGestureView.swift` with the policy first:

```swift
import CoreGraphics

struct VideoCanvasPinchPanGesturePolicy {

    // MARK: - Public Methods

    static func translation(
        from startLocation: CGPoint,
        to currentLocation: CGPoint
    ) -> CGSize {
        guard
            startLocation.x.isFinite,
            startLocation.y.isFinite,
            currentLocation.x.isFinite,
            currentLocation.y.isFinite
        else {
            return .zero
        }

        return CGSize(
            width: currentLocation.x - startLocation.x,
            height: currentLocation.y - startLocation.y
        )
    }

}
```

- [ ] **Step 3: Run the new tests**

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:VideoEditorKitTests/VideoCanvasPinchPanGesturePolicyTests \
  test
```

Expected: PASS.

- [ ] **Step 4: Commit the policy**

Run:

```bash
git add Sources/VideoEditorKit/Internal/Gestures/VideoCanvasInteractionGestureView.swift Tests/VideoEditorKitTests/VideoCanvasPinchPanGesturePolicyTests.swift
git commit -m "test: add pinch pan gesture policy"
```

---

### Task 3: Implement UIKit Gesture Bridge Outside Views

**Files:**
- Modify: `Sources/VideoEditorKit/Internal/Gestures/VideoCanvasInteractionGestureView.swift`

- [ ] **Step 1: Expand the gesture bridge file**

Replace the contents of `Sources/VideoEditorKit/Internal/Gestures/VideoCanvasInteractionGestureView.swift` with:

```swift
import CoreGraphics
import SwiftUI

struct VideoCanvasPinchPanGesturePolicy {

    // MARK: - Public Methods

    static func translation(
        from startLocation: CGPoint,
        to currentLocation: CGPoint
    ) -> CGSize {
        guard
            startLocation.x.isFinite,
            startLocation.y.isFinite,
            currentLocation.x.isFinite,
            currentLocation.y.isFinite
        else {
            return .zero
        }

        return CGSize(
            width: currentLocation.x - startLocation.x,
            height: currentLocation.y - startLocation.y
        )
    }

}

struct VideoCanvasInteractionGestureView: UIViewRepresentable {

    // MARK: - Public Properties

    var onPanChanged: (CGSize) -> Void
    var onPanEnded: () -> Void
    var onPinchChanged: (_ magnification: CGFloat, _ anchor: CGPoint, _ translation: CGSize) -> Void
    var onPinchEnded: () -> Void

    // MARK: - Public Methods

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true

        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        panGesture.maximumNumberOfTouches = 1
        panGesture.cancelsTouchesInView = false
        panGesture.delegate = context.coordinator
        view.addGestureRecognizer(panGesture)

        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        pinchGesture.cancelsTouchesInView = false
        pinchGesture.delegate = context.coordinator
        view.addGestureRecognizer(pinchGesture)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        // MARK: - Public Properties

        var parent: VideoCanvasInteractionGestureView

        // MARK: - Private Properties

        private var pinchStartLocation: CGPoint?

        // MARK: - Initializer

        init(_ parent: VideoCanvasInteractionGestureView) {
            self.parent = parent
        }

        // MARK: - Public Methods

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc
        func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: recognizer.view)

            switch recognizer.state {
            case .began, .changed:
                parent.onPanChanged(translation)
            case .ended, .cancelled, .failed:
                parent.onPanEnded()
            default:
                break
            }
        }

        @objc
        func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            let currentLocation = recognizer.location(in: recognizer.view)

            switch recognizer.state {
            case .began:
                pinchStartLocation = currentLocation
                parent.onPinchChanged(recognizer.scale, currentLocation, .zero)
            case .changed:
                let startLocation = pinchStartLocation ?? currentLocation
                let translation = VideoCanvasPinchPanGesturePolicy.translation(
                    from: startLocation,
                    to: currentLocation
                )
                parent.onPinchChanged(recognizer.scale, startLocation, translation)
            case .ended, .cancelled, .failed:
                pinchStartLocation = nil
                parent.onPinchEnded()
            default:
                break
            }
        }
    }

}
```

- [ ] **Step 2: Build package tests to catch compile errors**

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:VideoEditorKitTests/VideoCanvasPinchPanGesturePolicyTests \
  test
```

Expected: PASS and no compile errors from the UIKit bridge.

- [ ] **Step 3: Commit the bridge**

Run:

```bash
git add Sources/VideoEditorKit/Internal/Gestures/VideoCanvasInteractionGestureView.swift
git commit -m "feat: add canvas pinch pan gesture bridge"
```

---

### Task 4: Wire The Bridge Into VideoCanvasPreviewView

**Files:**
- Modify: `Sources/VideoEditorKit/Views/Canvas/VideoCanvasPreviewView.swift`

- [ ] **Step 1: Replace SwiftUI gesture attachment with overlay bridge**

In `canvasView(_:effectiveSnapshot:)`, replace:

```swift
        if isInteractive {
            canvas.gesture(interactiveGesture(layout: layout))
        } else {
            canvas
        }
```

with:

```swift
        if isInteractive {
            canvas.overlay {
                VideoCanvasInteractionGestureView(
                    onPanChanged: { translation in
                        updateDrag(translation)
                    },
                    onPanEnded: {
                        endDrag(
                            previewCanvasSize: layout.previewCanvasSize
                        )
                    },
                    onPinchChanged: { magnification, anchor, translation in
                        updateMagnification(
                            magnification: magnification,
                            anchor: anchor,
                            translation: translation
                        )
                    },
                    onPinchEnded: {
                        endMagnification(
                            previewCanvasSize: layout.previewCanvasSize
                        )
                    }
                )
            }
        } else {
            canvas
        }
```

- [ ] **Step 2: Remove the obsolete SwiftUI gesture method**

Delete the whole `interactiveGesture(layout:) -> some Gesture` method from `VideoCanvasPreviewView.swift`.

- [ ] **Step 3: Replace the magnification updater**

Replace:

```swift
    private func updateMagnification(
        _ value: MagnifyGesture.Value
    ) {
        let isStartingInteraction = interactionState == nil
        var interactionState =
            interactionState
            ?? .init(
                baselineTransform: editorState.transform
            )
        interactionState.magnification = value.magnification
        interactionState.magnificationAnchor = value.startLocation
        interactionState.isMagnifying = true
        self.interactionState = interactionState

        if isStartingInteraction {
            onInteractionStarted()
        }
    }
```

with:

```swift
    private func updateMagnification(
        magnification: CGFloat,
        anchor: CGPoint,
        translation: CGSize
    ) {
        let isStartingInteraction = interactionState == nil
        var interactionState =
            interactionState
            ?? .init(
                baselineTransform: editorState.transform
            )
        interactionState.magnification = magnification
        interactionState.magnificationAnchor = anchor
        interactionState.translation = translation
        interactionState.isMagnifying = true
        self.interactionState = interactionState

        if isStartingInteraction {
            onInteractionStarted()
        }
    }
```

- [ ] **Step 4: Run canvas preview tests**

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:VideoEditorKitTests/VideoCanvasPreviewViewTests \
  -only-testing:VideoEditorKitTests/VideoCanvasPinchPanGesturePolicyTests \
  -only-testing:VideoEditorKitTests/VideoCanvasMappingActorTests \
  test
```

Expected: PASS.

- [ ] **Step 5: Commit the preview wiring**

Run:

```bash
git add Sources/VideoEditorKit/Views/Canvas/VideoCanvasPreviewView.swift
git commit -m "feat: pan video while pinching preview"
```

---

### Task 5: Manual Simulator Verification

**Files:**
- No file changes.

- [ ] **Step 1: Run the example app tests**

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

- [ ] **Step 2: Launch the example app on simulator**

Run:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditor \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Verify gestures manually**

Open the example app on an iPhone 17 simulator and verify:

```text
1. Open a video in the editor.
2. Choose a canvas preset where the video can be repositioned, such as Original or a social preset.
3. Drag with one finger on the preview.
   Expected: the video pans.
4. Pinch in or out without moving the pinch midpoint.
   Expected: the video zooms around the starting midpoint.
5. Pinch while moving both fingers together horizontally and vertically.
   Expected: the video zooms and follows the moving pinch midpoint.
6. End the pinch.
   Expected: the final transform is retained, no jump occurs when fingers lift.
7. Double tap the canvas.
   Expected: transform resets as before.
8. Use explicit rotation controls.
   Expected: rotation behavior is unchanged.
```

---

### Task 6: Format And Full Validation

**Files:**
- No intentional source changes beyond formatting.

- [ ] **Step 1: Format Swift**

Run:

```bash
scripts/format-swift.sh
```

Expected: formatting completes without errors.

- [ ] **Step 2: Run full validation**

Run:

```bash
scripts/test-ios.sh
```

Expected: PASS.

- [ ] **Step 3: Inspect final diff**

Run:

```bash
git diff -- Sources/VideoEditorKit/Internal/Gestures/VideoCanvasInteractionGestureView.swift Sources/VideoEditorKit/Views/Canvas/VideoCanvasPreviewView.swift Tests/VideoEditorKitTests/VideoCanvasMappingActorTests.swift Tests/VideoEditorKitTests/VideoCanvasPinchPanGesturePolicyTests.swift
```

Expected:

```text
- UIKit imports appear only in Sources/VideoEditorKit/Internal/Gestures/VideoCanvasInteractionGestureView.swift.
- Sources/VideoEditorKit/Views/Canvas/VideoCanvasPreviewView.swift still imports SwiftUI only.
- The preview still commits snapshots only when gestures end.
- No force unwraps or operational print statements were added.
```

- [ ] **Step 4: Commit formatting or validation fixes if needed**

Run only if formatting changed files:

```bash
git add Sources/VideoEditorKit/Internal/Gestures/VideoCanvasInteractionGestureView.swift Sources/VideoEditorKit/Views/Canvas/VideoCanvasPreviewView.swift Tests/VideoEditorKitTests/VideoCanvasMappingActorTests.swift Tests/VideoEditorKitTests/VideoCanvasPinchPanGesturePolicyTests.swift
git commit -m "style: format pinch pan preview changes"
```

---

## Self-Review

- Spec coverage: the plan covers simultaneous pinch zoom and movement, preserves one-finger pan, preserves double-tap reset, and keeps rotation explicit.
- Project rules: UIKit is isolated outside `Views/`; no iOS availability checks are added for versions at or below the deployment target; tests use Swift Testing; validation avoids `swift test`.
- Risk: replacing SwiftUI gestures with a UIKit overlay could affect tap routing. The plan keeps double tap on the SwiftUI canvas, so manual verification must confirm the overlay does not swallow double taps. If it does, move double-tap handling into the UIKit bridge in the same file and call the existing reset path from a new `onDoubleTap` closure.
