//
//  CropView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct CropView<T: View>: View {

    // MARK: - States

    @State private var position: CGPoint = .zero
    @State private var size: CGSize = .zero
    @State private var clipped: Bool = false

    // MARK: - Public Properties

    private let originalSize: CGSize
    private let rotation: Double?
    private let isMirror: Bool
    private let isActiveCrop: Bool
    private let setFrameScale: Bool
    private let frameScale: CGFloat
    @ViewBuilder
    private var frameView: () -> T

    // MARK: - Body

    var body: some View {
        ZStack {
            frameView()

            if isActiveCrop {
                ZStack {
                    Theme.scrim
                    Rectangle()
                        .fill(Theme.scrim.opacity(0.35))
                        .frame(width: size.width, height: size.height)
                        .overlay(Rectangle().stroke(Theme.primary, lineWidth: lineWidth))
                        .position(position)
                        .gesture(
                            DragGesture()
                                .onChanged { value in

                                    let sizeWithBorder: CGSize = .init(
                                        width: size.width + lineWidth, height: size.height + lineWidth)

                                    // limit movement to min and max value
                                    let limitedX = max(
                                        min(value.location.x, originalSize.width - sizeWithBorder.width / 2),
                                        sizeWithBorder.width / 2)
                                    let limitedY = max(
                                        min(value.location.y, originalSize.height - (sizeWithBorder.height) / 2),
                                        sizeWithBorder.height / 2)

                                    self.position = CGPoint(
                                        x: limitedX,
                                        y: limitedY)
                                }
                        )
                        .onTapGesture {
                            clipped.toggle()
                        }
                }
                .onAppear {
                    updateCropState(for: originalSize)
                }
                .onChange(of: originalSize) { _, newValue in
                    updateCropState(for: newValue)
                }
            }
        }
        .frame(width: originalSize.width, height: originalSize.height)
        .border(isActiveCrop ? Theme.primary : .clear)
        .rotationEffect(.degrees(rotation ?? 0))
        .rotation3DEffect(.degrees(isMirror ? 180 : 0), axis: (x: 0, y: 1, z: 0))
    }

    // MARK: - Private Properties

    private let lineWidth: CGFloat = 2

    // MARK: - Initializer

    init(
        originalSize: CGSize,
        rotation: Double?,
        isMirror: Bool,
        isActiveCrop: Bool,
        setFrameScale: Bool = false,
        frameScale: CGFloat = 1,
        @ViewBuilder frameView: @escaping () -> T
    ) {
        self.originalSize = originalSize
        self.rotation = rotation
        self.isMirror = isMirror
        self.isActiveCrop = isActiveCrop
        self.setFrameScale = setFrameScale
        self.frameScale = frameScale
        self.frameView = frameView
    }

    // MARK: - Private Methods

    private func updateCropState(for size: CGSize) {
        position = .init(x: size.width / 2, y: size.height / 2)
        self.size = .init(
            width: max(size.width - 100, size.width * 0.55),
            height: max(size.height - 100, size.height * 0.55)
        )
    }

}

#Preview {
    GeometryReader { proxy in
        CropView(originalSize: .init(width: 300, height: 600), rotation: 0, isMirror: false, isActiveCrop: true) {
            Rectangle()
                .fill(Color.secondary)
        }
        .allFrame()
        .frame(height: proxy.size.height / 1.45, alignment: .center)
    }
}

struct CropFrame: Shape {

    // MARK: - Public Properties

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

    // MARK: - Public Properties

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

    init(frameSize: Binding<CGSize>, originalSize: CGSize, @ViewBuilder frameView: @escaping () -> T) {
        self._frameSize = frameSize
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
