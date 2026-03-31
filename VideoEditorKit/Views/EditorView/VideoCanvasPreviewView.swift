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

    @State private var layout: VideoCanvasLayout?
    @State private var availableSize: CGSize = .zero
    @State private var dragBaselineTransform: VideoCanvasTransform?
    @State private var magnificationBaselineTransform: VideoCanvasTransform?
    @State private var rotationBaselineTransform: VideoCanvasTransform?

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
            ZStack {
                if let layout {
                    canvasView(layout)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .task(id: taskKey(for: proxy.size)) {
                availableSize = proxy.size
                await refreshLayout(for: proxy.size)
            }
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
                .allowsHitTesting(false)
        }
        .onTapGesture(count: 2) {
            guard isInteractive else { return }
            editorState.resetTransform()
            onSnapshotChange(editorState.snapshot())

            Task { @MainActor in
                await refreshLayout(for: availableSize)
            }
        }

        if isInteractive {
            canvas.gesture(interactiveGesture(layout: layout))
        } else {
            canvas
        }
    }

    private func taskKey(for size: CGSize) -> PreviewTaskKey {
        PreviewTaskKey(
            source: source,
            snapshot: editorState.snapshot(),
            availableSize: size
        )
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
                    },
                MagnificationGesture()
                    .onChanged { value in
                        updateMagnification(value)
                    }
                    .onEnded { _ in
                        magnificationBaselineTransform = nil
                    }
            ),
            RotationGesture()
                .onChanged { value in
                    updateRotation(value)
                }
                .onEnded { _ in
                    rotationBaselineTransform = nil
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

        Task { @MainActor in
            editorState.transform = await editorState.dragTransform(
                from: baseline,
                translation: translation,
                previewCanvasSize: previewCanvasSize
            )
            onSnapshotChange(editorState.snapshot())
            await refreshLayout(for: availableSize)
        }
    }

    private func updateMagnification(
        _ magnification: CGFloat
    ) {
        let baseline = magnificationBaselineTransform ?? editorState.transform
        if magnificationBaselineTransform == nil {
            magnificationBaselineTransform = baseline
        }

        Task { @MainActor in
            editorState.transform = await editorState.magnifiedTransform(
                from: baseline,
                magnification: magnification
            )
            onSnapshotChange(editorState.snapshot())
            await refreshLayout(for: availableSize)
        }
    }

    private func updateRotation(
        _ rotation: Angle
    ) {
        let baseline = rotationBaselineTransform ?? editorState.transform
        if rotationBaselineTransform == nil {
            rotationBaselineTransform = baseline
        }

        Task { @MainActor in
            editorState.transform = await editorState.rotatedTransform(
                from: baseline,
                rotation: rotation
            )
            onSnapshotChange(editorState.snapshot())
            await refreshLayout(for: availableSize)
        }
    }

    private func refreshLayout(
        for size: CGSize
    ) async {
        layout = await editorState.previewLayout(
            source: source,
            availableSize: size
        )
    }

}

private struct PreviewTaskKey: Equatable {

    // MARK: - Public Properties

    let source: VideoCanvasSourceDescriptor
    let snapshot: VideoCanvasSnapshot
    let availableSize: CGSize

}
