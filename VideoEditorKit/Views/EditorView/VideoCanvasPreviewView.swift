//
//  VideoCanvasPreviewView.swift
//  VideoEditorKit
//
//  Created by Codex on 31.03.2026.
//

import SwiftUI

@MainActor
struct VideoCanvasPreviewView<Content: View, Overlay: View>: View {

    // MARK: - Bindables

    @Bindable private var editorState: VideoCanvasEditorState

    // MARK: - States

    @State private var dragBaselineTransform: VideoCanvasTransform?
    @State private var magnificationBaselineTransform: VideoCanvasTransform?
    @State private var rotationBaselineTransform: VideoCanvasTransform?
    @State private var hasPendingInteractiveChange = false

    // MARK: - Public Properties

    private let source: VideoCanvasSourceDescriptor
    private let isInteractive: Bool
    private let cornerRadius: CGFloat
    private let onSnapshotChange: @MainActor (VideoCanvasSnapshot) -> Void
    @ViewBuilder
    private var content: () -> Content
    @ViewBuilder
    private var overlayContent: () -> Overlay

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let layout = editorState.previewLayout(
                source: source,
                availableSize: proxy.size
            )

            ZStack {
                if layout.previewCanvasSize.width > 0, layout.previewCanvasSize.height > 0 {
                    canvasView(layout)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    // MARK: - Private Properties

    @ViewBuilder
    private func canvasView(_ layout: VideoCanvasLayout) -> some View {
        let contentScaleX = layout.isMirrored ? -layout.contentScale : layout.contentScale

        let canvas = ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.black)

            content()
                .frame(
                    width: layout.contentBaseSize.width,
                    height: layout.contentBaseSize.height
                )
                .scaleEffect(x: contentScaleX, y: layout.contentScale)
                .rotationEffect(.radians(layout.totalRotationRadians))
                .position(layout.contentCenter)
        }
        .frame(
            width: layout.previewCanvasSize.width,
            height: layout.previewCanvasSize.height
        )
        .clipShape(.rect(cornerRadius: cornerRadius))
        .contentShape(Rectangle())
        .overlay {
            overlayContent()
        }
        .onTapGesture(count: 2) {
            guard isInteractive else { return }
            editorState.resetTransform()
            onSnapshotChange(editorState.snapshot())
        }

        if isInteractive {
            canvas.gesture(interactiveGesture(layout: layout))
        } else {
            canvas
        }
    }

    // MARK: - Initializer

    init(
        _ editorState: VideoCanvasEditorState,
        source: VideoCanvasSourceDescriptor,
        isInteractive: Bool,
        cornerRadius: CGFloat = 28,
        onSnapshotChange: @escaping @MainActor (VideoCanvasSnapshot) -> Void = { _ in },
        @ViewBuilder content: @escaping () -> Content
    )
    where Overlay == EmptyView {
        self.editorState = editorState
        self.source = source
        self.isInteractive = isInteractive
        self.cornerRadius = cornerRadius
        self.onSnapshotChange = onSnapshotChange
        self.content = content
        self.overlayContent = { EmptyView() }
    }

    init(
        _ editorState: VideoCanvasEditorState,
        source: VideoCanvasSourceDescriptor,
        isInteractive: Bool,
        cornerRadius: CGFloat = 28,
        onSnapshotChange: @escaping @MainActor (VideoCanvasSnapshot) -> Void = { _ in },
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.editorState = editorState
        self.source = source
        self.isInteractive = isInteractive
        self.cornerRadius = cornerRadius
        self.onSnapshotChange = onSnapshotChange
        self.content = content
        self.overlayContent = overlay
    }

    // MARK: - Private Methods

    private func interactiveGesture(
        layout: VideoCanvasLayout
    ) -> some Gesture {
        SimultaneousGesture(
            SimultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        updateDrag(
                            value.translation,
                            previewCanvasSize: layout.previewCanvasSize
                        )
                    }
                    .onEnded { _ in
                        dragBaselineTransform = nil
                        commitInteractiveChangesIfNeeded()
                    },
                MagnifyGesture()
                    .onChanged { value in
                        updateMagnification(
                            value,
                            previewCanvasSize: layout.previewCanvasSize
                        )
                    }
                    .onEnded { _ in
                        magnificationBaselineTransform = nil
                        commitInteractiveChangesIfNeeded()
                    }
            ),
            RotationGesture()
                .onChanged { value in
                    updateRotation(value)
                }
                .onEnded { _ in
                    rotationBaselineTransform = nil
                    commitInteractiveChangesIfNeeded()
                }
        )
    }

    private func updateDrag(
        _ translation: CGSize,
        previewCanvasSize: CGSize
    ) {
        let baseline = dragBaselineTransform ?? editorState.transform
        if dragBaselineTransform == nil {
            dragBaselineTransform = baseline
        }

        editorState.transform = editorState.dragTransform(
            from: baseline,
            translation: translation,
            previewCanvasSize: previewCanvasSize
        )
        hasPendingInteractiveChange = true
    }

    private func updateMagnification(
        _ value: MagnifyGesture.Value,
        previewCanvasSize: CGSize
    ) {
        let baseline = magnificationBaselineTransform ?? editorState.transform
        if magnificationBaselineTransform == nil {
            magnificationBaselineTransform = baseline
        }

        editorState.transform = editorState.magnifiedTransform(
            from: baseline,
            magnification: value.magnification,
            anchor: value.startLocation,
            previewCanvasSize: previewCanvasSize
        )
        hasPendingInteractiveChange = true
    }

    private func updateRotation(
        _ rotation: Angle
    ) {
        let baseline = rotationBaselineTransform ?? editorState.transform
        if rotationBaselineTransform == nil {
            rotationBaselineTransform = baseline
        }

        editorState.transform = editorState.rotatedTransform(
            from: baseline,
            rotation: rotation
        )
        hasPendingInteractiveChange = true
    }

    private func commitInteractiveChangesIfNeeded() {
        let isInteractionActive =
            dragBaselineTransform != nil
            || magnificationBaselineTransform != nil
            || rotationBaselineTransform != nil

        guard hasPendingInteractiveChange, isInteractionActive == false else { return }

        hasPendingInteractiveChange = false
        onSnapshotChange(editorState.snapshot())
    }

}
