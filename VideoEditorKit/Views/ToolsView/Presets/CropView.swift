//
//  CropView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct CropView<T: View>: View {

    // MARK: - Bindings

    @Binding private var freeformRect: VideoEditingConfiguration.FreeformRect?

    // MARK: - States

    @State private var dragStartRect: VideoEditingConfiguration.FreeformRect?
    @State private var pinchStartRect: VideoEditingConfiguration.FreeformRect?

    // MARK: - Private Properties

    private let referenceSize: CGSize
    private let contentSize: CGSize
    private let previewViewportSize: CGSize?
    private let rotation: Double?
    private let isMirror: Bool
    private let showsCropOverlay: Bool
    private let isInteractiveCrop: Bool
    private let setFrameScale: Bool
    private let frameScale: CGFloat
    @ViewBuilder
    private var frameView: () -> T

    // MARK: - Body

    var body: some View {
        interactivePreview {
            ZStack {
                transformedFrameView

                if showsCropOverlay {
                    cropOverlay
                }
            }
            .frame(width: resolvedViewportSize.width, height: resolvedViewportSize.height)
            .rotationEffect(.degrees(rotation ?? 0))
            .rotation3DEffect(.degrees(isMirror ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        }
    }

    // MARK: - Private Properties

    @ViewBuilder
    private func interactivePreview<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        if isInteractiveCrop {
            content()
                .contentShape(Rectangle())
                .gesture(cropGesture)
                .onTapGesture(count: 2) {
                    resetCropRectToPresetFullFrame()
                }
        } else {
            content()
        }
    }

    private var cropOverlay: some View {
        standardOverlayContent
            .allowsHitTesting(false)
    }

    private var cropGesture: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { value in
                    updateCropRect(translation: value.translation)
                }
                .onEnded { _ in
                    dragStartRect = nil
                },
            MagnificationGesture()
                .onChanged { value in
                    updateCropRectScale(value)
                }
                .onEnded { _ in
                    pinchStartRect = nil
                }
        )
    }

    // MARK: - Private Properties

    private let lineWidth: CGFloat = 2
    private let cropCornerRadius: CGFloat = 12

    private var previewLayout: VideoCropPreviewLayout? {
        makePreviewLayout(freeformRect: freeformRect)
    }

    private var resolvedViewportSize: CGSize {
        if let previewViewportSize {
            return previewViewportSize
        }

        return contentSize
    }

    private var resolvedCropRect: CGRect {
        if let previewLayout {
            return previewLayout.viewportRect
        }

        return displayedRect(
            from: boundedRect(decodedRect(from: freeformRect) ?? defaultCropRect())
        )
    }

    private var contentScale: CGFloat {
        previewLayout?.contentScale ?? 1
    }

    private var contentOffset: CGSize {
        previewLayout?.contentOffset ?? .zero
    }

    private var transformedFrameView: some View {
        ZStack(alignment: .topLeading) {
            frameView()
                .frame(width: contentSize.width, height: contentSize.height)
                .scaleEffect(
                    x: contentScale,
                    y: contentScale,
                    anchor: .topLeading
                )
                .offset(contentOffset)
        }
        .frame(
            width: resolvedViewportSize.width,
            height: resolvedViewportSize.height,
            alignment: .topLeading
        )
        .clipped()
        .allowsHitTesting(false)
    }

    private var standardOverlayContent: some View {
        ZStack {
            CropOverlayShape(
                cropRect: resolvedCropRect,
                cornerRadius: cropCornerRadius
            )
            .fill(.black.opacity(0.72), style: FillStyle(eoFill: true))

            RoundedRectangle(cornerRadius: cropCornerRadius, style: .continuous)
                .stroke(Theme.primary, lineWidth: lineWidth)
                .frame(
                    width: resolvedCropRect.width,
                    height: resolvedCropRect.height
                )
                .position(
                    x: resolvedCropRect.midX,
                    y: resolvedCropRect.midY
                )
        }
    }

    // MARK: - Initializer

    init(
        _ referenceSize: CGSize,
        freeformRect: Binding<VideoEditingConfiguration.FreeformRect?>,
        contentSize: CGSize? = nil,
        rotation: Double?,
        isMirror: Bool,
        showsCropOverlay: Bool,
        isInteractiveCrop: Bool,
        viewportSize: CGSize? = nil,
        setFrameScale: Bool = false,
        frameScale: CGFloat = 1,
        @ViewBuilder frameView: @escaping () -> T
    ) {
        _freeformRect = freeformRect

        self.referenceSize = referenceSize
        self.contentSize = contentSize ?? referenceSize
        self.previewViewportSize = viewportSize
        self.rotation = rotation
        self.isMirror = isMirror
        self.showsCropOverlay = showsCropOverlay
        self.isInteractiveCrop = isInteractiveCrop
        self.setFrameScale = setFrameScale
        self.frameScale = frameScale
        self.frameView = frameView
    }

    // MARK: - Private Methods

    private func updateCropRect(translation: CGSize) {
        if dragStartRect == nil {
            dragStartRect = freeformRect ?? encodedRect(defaultCropRect())
        }

        guard
            let dragStartRect,
            let startRect = decodedRect(from: dragStartRect)
        else { return }

        let dragLayout = makePreviewLayout(freeformRect: dragStartRect)
        let sourceTranslation = dragLayout?.sourceTranslation(for: translation) ?? translation
        let deltaX = sourceTranslation.width
        let deltaY = sourceTranslation.height
        let updatedRect = CGRect(
            x: startRect.origin.x + deltaX,
            y: startRect.origin.y + deltaY,
            width: startRect.width,
            height: startRect.height
        )

        freeformRect = encodedRect(updatedRect)
    }

    private func updateCropRectScale(_ value: CGFloat) {
        guard value.isFinite, value > 0 else { return }

        if pinchStartRect == nil {
            pinchStartRect = freeformRect ?? encodedRect(defaultCropRect())
        }

        freeformRect = VideoCropFormatPreset.resizedRect(
            matching: pinchStartRect,
            in: referenceSize,
            magnification: value
        )
    }

    private func resetCropRectToPresetFullFrame() {
        freeformRect = VideoCropFormatPreset.resetRect(
            matching: freeformRect,
            in: referenceSize
        )
    }

    private func defaultCropRect() -> CGRect {
        let defaultWidth = max(referenceSize.width - 100, referenceSize.width * 0.55)
        let defaultHeight = max(referenceSize.height - 100, referenceSize.height * 0.55)
        let rect = CGRect(
            x: (referenceSize.width - defaultWidth) / 2,
            y: (referenceSize.height - defaultHeight) / 2,
            width: defaultWidth,
            height: defaultHeight
        )

        return boundedRect(rect)
    }

    private func decodedRect(
        from serializedRect: VideoEditingConfiguration.FreeformRect?
    ) -> CGRect? {
        guard let serializedRect else { return nil }
        guard referenceSize.width > 0, referenceSize.height > 0 else { return nil }

        return CGRect(
            x: serializedRect.x * referenceSize.width,
            y: serializedRect.y * referenceSize.height,
            width: serializedRect.width * referenceSize.width,
            height: serializedRect.height * referenceSize.height
        )
    }

    private func encodedRect(_ rect: CGRect) -> VideoEditingConfiguration.FreeformRect? {
        guard referenceSize.width > 0, referenceSize.height > 0 else { return nil }

        let boundedRect = boundedRect(rect)
        guard boundedRect.width > 0, boundedRect.height > 0 else { return nil }

        return .init(
            x: boundedRect.origin.x / referenceSize.width,
            y: boundedRect.origin.y / referenceSize.height,
            width: boundedRect.width / referenceSize.width,
            height: boundedRect.height / referenceSize.height
        )
    }

    private func boundedRect(_ rect: CGRect) -> CGRect {
        guard referenceSize.width > 0, referenceSize.height > 0 else { return .zero }

        let minWidth = min(referenceSize.width * 0.2, referenceSize.width)
        let minHeight = min(referenceSize.height * 0.2, referenceSize.height)
        let width = rect.width.bounded(lowerBound: minWidth, uppderBound: referenceSize.width)
        let height = rect.height.bounded(lowerBound: minHeight, uppderBound: referenceSize.height)
        let originX = rect.origin.x.bounded(lowerBound: 0, uppderBound: referenceSize.width - width)
        let originY = rect.origin.y.bounded(lowerBound: 0, uppderBound: referenceSize.height - height)

        return CGRect(
            x: originX,
            y: originY,
            width: width,
            height: height
        )
    }

    private func makePreviewLayout(
        freeformRect: VideoEditingConfiguration.FreeformRect?
    ) -> VideoCropPreviewLayout? {
        if let previewViewportSize {
            return VideoCropPreviewLayout(
                freeformRect: freeformRect,
                referenceSize: referenceSize,
                contentSize: contentSize,
                viewportSize: previewViewportSize
            )
        }

        return nil
    }

    private func displayedRect(from referenceRect: CGRect) -> CGRect {
        guard referenceSize.width > 0, referenceSize.height > 0 else { return .zero }

        let scale = min(
            contentSize.width / referenceSize.width,
            contentSize.height / referenceSize.height
        )

        return CGRect(
            x: referenceRect.minX * scale,
            y: referenceRect.minY * scale,
            width: referenceRect.width * scale,
            height: referenceRect.height * scale
        )
    }

}

private struct CropOverlayShape: Shape {

    // MARK: - Private Properties

    let cropRect: CGRect
    let cornerRadius: CGFloat

    // MARK: - Public Methods

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(
            in: cropRect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )
        return path
    }

}

#Preview {
    CropView(
        .init(width: 300, height: 600),
        freeformRect: .constant(nil),
        rotation: 0,
        isMirror: false,
        showsCropOverlay: true,
        isInteractiveCrop: true
    ) {
        Rectangle()
            .fill(Color.secondary)
    }
}

extension Comparable {

    // MARK: - Public Methods

    func bounded(lowerBound: Self, uppderBound: Self) -> Self {
        max(lowerBound, min(self, uppderBound))
    }

}
