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

    @State private var pinchStartRect: VideoEditingConfiguration.FreeformRect?

    // MARK: - Private Properties

    private let originalSize: CGSize
    private let rotation: Double?
    private let isMirror: Bool
    private let isActiveCrop: Bool
    private let socialVideoSafeAreaGuide: SocialVideoSafeAreaGuide?
    private let showsSocialVideoSafeAreaGuide: Bool
    private let setFrameScale: Bool
    private let frameScale: CGFloat
    @ViewBuilder
    private var frameView: () -> T

    // MARK: - Body

    var body: some View {
        ZStack {
            frameView()

            if isActiveCrop {
                cropOverlay
            }
        }
        .frame(width: originalSize.width, height: originalSize.height)
        .border(isActiveCrop ? Theme.primary : .clear)
        .rotationEffect(.degrees(rotation ?? 0))
        .rotation3DEffect(.degrees(isMirror ? 180 : 0), axis: (x: 0, y: 1, z: 0))
    }

    // MARK: - Private Properties

    private let lineWidth: CGFloat = 2
    private let cropCornerRadius: CGFloat = 12

    private var resolvedCropRect: CGRect {
        boundedRect(decodedRect(from: freeformRect) ?? defaultCropRect())
    }

    private var cropOverlay: some View {
        ZStack {
            CropOverlayShape(
                cropRect: resolvedCropRect,
                cornerRadius: cropCornerRadius
            )
            .fill(.black.opacity(0.72), style: FillStyle(eoFill: true))

            if let socialVideoSafeAreaGuide, showsSocialVideoSafeAreaGuide {
                CropSafeAreaOverlay(
                    guide: socialVideoSafeAreaGuide,
                    cropSize: resolvedCropRect.size,
                    cornerRadius: cropCornerRadius
                )
                .position(
                    x: resolvedCropRect.midX,
                    y: resolvedCropRect.midY
                )
            }

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
        .contentShape(Rectangle())
        .gesture(cropGesture)
        .onTapGesture(count: 2) {
            resetCropRectToPresetFullFrame()
        }
    }

    private var cropGesture: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { value in
                    updateCropRect(center: value.location)
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

    // MARK: - Initializer

    init(
        _ originalSize: CGSize,
        freeformRect: Binding<VideoEditingConfiguration.FreeformRect?>,
        rotation: Double?,
        isMirror: Bool,
        isActiveCrop: Bool,
        socialVideoSafeAreaGuide: SocialVideoSafeAreaGuide? = nil,
        showsSocialVideoSafeAreaGuide: Bool = false,
        setFrameScale: Bool = false,
        frameScale: CGFloat = 1,
        @ViewBuilder frameView: @escaping () -> T
    ) {
        _freeformRect = freeformRect

        self.originalSize = originalSize
        self.rotation = rotation
        self.isMirror = isMirror
        self.isActiveCrop = isActiveCrop
        self.socialVideoSafeAreaGuide = socialVideoSafeAreaGuide
        self.showsSocialVideoSafeAreaGuide = showsSocialVideoSafeAreaGuide
        self.setFrameScale = setFrameScale
        self.frameScale = frameScale
        self.frameView = frameView
    }

    // MARK: - Private Methods

    private func updateCropRect(center: CGPoint) {
        let rect = resolvedCropRect
        let boundedCenterX = center.x.bounded(
            lowerBound: rect.width / 2,
            uppderBound: originalSize.width - rect.width / 2
        )
        let boundedCenterY = center.y.bounded(
            lowerBound: rect.height / 2,
            uppderBound: originalSize.height - rect.height / 2
        )

        let updatedRect = CGRect(
            x: boundedCenterX - rect.width / 2,
            y: boundedCenterY - rect.height / 2,
            width: rect.width,
            height: rect.height
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
            in: originalSize,
            magnification: value
        )
    }

    private func resetCropRectToPresetFullFrame() {
        freeformRect = VideoCropFormatPreset.resetRect(
            matching: freeformRect,
            in: originalSize
        )
    }

    private func defaultCropRect() -> CGRect {
        let defaultWidth = max(originalSize.width - 100, originalSize.width * 0.55)
        let defaultHeight = max(originalSize.height - 100, originalSize.height * 0.55)
        let rect = CGRect(
            x: (originalSize.width - defaultWidth) / 2,
            y: (originalSize.height - defaultHeight) / 2,
            width: defaultWidth,
            height: defaultHeight
        )

        return boundedRect(rect)
    }

    private func decodedRect(
        from serializedRect: VideoEditingConfiguration.FreeformRect?
    ) -> CGRect? {
        guard let serializedRect else { return nil }
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }

        return CGRect(
            x: serializedRect.x * originalSize.width,
            y: serializedRect.y * originalSize.height,
            width: serializedRect.width * originalSize.width,
            height: serializedRect.height * originalSize.height
        )
    }

    private func encodedRect(_ rect: CGRect) -> VideoEditingConfiguration.FreeformRect? {
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }

        let boundedRect = boundedRect(rect)
        guard boundedRect.width > 0, boundedRect.height > 0 else { return nil }

        return .init(
            x: boundedRect.origin.x / originalSize.width,
            y: boundedRect.origin.y / originalSize.height,
            width: boundedRect.width / originalSize.width,
            height: boundedRect.height / originalSize.height
        )
    }

    private func boundedRect(_ rect: CGRect) -> CGRect {
        guard originalSize.width > 0, originalSize.height > 0 else { return .zero }

        let minWidth = min(originalSize.width * 0.2, originalSize.width)
        let minHeight = min(originalSize.height * 0.2, originalSize.height)
        let width = rect.width.bounded(lowerBound: minWidth, uppderBound: originalSize.width)
        let height = rect.height.bounded(lowerBound: minHeight, uppderBound: originalSize.height)
        let originX = rect.origin.x.bounded(lowerBound: 0, uppderBound: originalSize.width - width)
        let originY = rect.origin.y.bounded(lowerBound: 0, uppderBound: originalSize.height - height)

        return CGRect(
            x: originX,
            y: originY,
            width: width,
            height: height
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

private struct CropSafeAreaOverlay: View {

    // MARK: - Private Properties

    private let guide: SocialVideoSafeAreaGuide
    private let cropSize: CGSize
    private let cornerRadius: CGFloat

    // MARK: - Body

    var body: some View {
        ZStack {
            ForEach(guide.overlayRegions(in: localCanvas)) { region in
                regionView(region)
            }

            RoundedRectangle(cornerRadius: max(cornerRadius - 3, 8), style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                .foregroundStyle(.white.opacity(0.9))
                .frame(
                    width: safeRect.width,
                    height: safeRect.height
                )
                .position(
                    x: safeRect.midX,
                    y: safeRect.midY
                )
        }
        .frame(width: cropSize.width, height: cropSize.height)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .allowsHitTesting(false)
    }

    // MARK: - Initializer

    init(
        guide: SocialVideoSafeAreaGuide,
        cropSize: CGSize,
        cornerRadius: CGFloat
    ) {
        self.guide = guide
        self.cropSize = cropSize
        self.cornerRadius = cornerRadius
    }

    // MARK: - Private Properties

    private var localCanvas: CGRect {
        CGRect(origin: .zero, size: cropSize)
    }

    private var safeRect: CGRect {
        guide.safeRect(in: localCanvas)
    }

    // MARK: - Private Methods

    @ViewBuilder
    private func regionView(_ region: SocialVideoSafeAreaGuide.Region) -> some View {
        Rectangle()
            .fill(color(for: region.role).opacity(0.18))
            .frame(
                width: region.rect.width,
                height: region.rect.height
            )
            .position(
                x: region.rect.midX,
                y: region.rect.midY
            )
            .overlay(alignment: alignment(for: region.role)) {
                Text(region.title)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .capsuleControl(
                        prominent: true,
                        tint: color(for: region.role).opacity(0.9)
                    )
                    .foregroundStyle(.white)
                    .padding(8)
            }
    }

    private func color(for role: SocialVideoSafeAreaGuide.Region.Role) -> Color {
        switch role {
        case .top:
            Color.orange
        case .bottom:
            Color.pink
        case .trailing:
            Color.cyan
        }
    }

    private func alignment(for role: SocialVideoSafeAreaGuide.Region.Role) -> Alignment {
        switch role {
        case .top:
            .topLeading
        case .bottom:
            .bottomLeading
        case .trailing:
            .topTrailing
        }
    }

}

#Preview {
    GeometryReader { proxy in
        CropPreviewHost()
            .allFrame()
            .frame(height: proxy.size.height / 1.45, alignment: .center)
    }
}

private struct CropPreviewHost: View {

    // MARK: - States

    @State private var freeformRect: VideoEditingConfiguration.FreeformRect?

    // MARK: - Body

    var body: some View {
        CropView(
            .init(width: 300, height: 600),
            freeformRect: $freeformRect,
            rotation: 0,
            isMirror: false,
            isActiveCrop: true
        ) {
            Rectangle()
                .fill(Color.secondary)
        }
    }

}

struct CropFrame: Shape {

    // MARK: - Private Properties

    let isActive: Bool
    let currentPosition: CGSize
    let size: CGSize

    // MARK: - Public Methods

    func path(in rect: CGRect) -> Path {
        guard isActive else { return Path(rect) }

        let size = CGSize(width: size.width, height: size.height)
        let origin = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        return Path(CGRect(origin: origin, size: size).integral)
    }

}

struct CropImage<T: View>: View {

    // MARK: - Bindings

    @Binding private var frameSize: CGSize

    // MARK: - States

    @State private var currentPosition: CGSize = .zero
    @State private var newPosition: CGSize = .zero
    @State private var clipped = false

    // MARK: - Private Properties

    private let originalSize: CGSize
    @ViewBuilder
    private var frameView: () -> T

    // MARK: - Body

    var body: some View {
        VStack {
            ZStack {
                frameView()
                    .offset(x: self.currentPosition.width, y: self.currentPosition.height)
                Rectangle()
                    .fill(Theme.scrim)
                    .frame(width: frameSize.width, height: frameSize.height)
                    .overlay(Rectangle().stroke(Theme.primary, lineWidth: 2))
            }
            .clipShape(
                CropFrame(isActive: clipped, currentPosition: currentPosition, size: frameSize)
            )
            .onChange(of: frameSize) { _, _ in
                currentPosition = .zero
                newPosition = .zero
            }

            Button(action: { self.clipped.toggle() }) {
                Text("Crop Image")
                    .padding(.all, 10)
                    .background(Theme.accent)
                    .padding(.top, 50)
            }
        }
    }

    // MARK: - Initializer

    init(_ frameSize: Binding<CGSize>, originalSize: CGSize, @ViewBuilder frameView: @escaping () -> T) {
        _frameSize = frameSize

        self.originalSize = originalSize
        self.frameView = frameView
    }

}

extension Comparable {

    // MARK: - Public Methods

    func bounded(lowerBound: Self, uppderBound: Self) -> Self {
        max(lowerBound, min(self, uppderBound))
    }

}
