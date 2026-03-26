//
//  NewTimelineSlider.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct TimelineSlider<T: View, A: View>: View {

    // MARK: - Bindings

    @Binding private var value: Double

    // MARK: - States

    @State private var lastOffset: CGFloat = 0
    @State private var isChange: Bool = false
    @State private var offset: CGFloat = 0
    @State private var gestureW: CGFloat = 0

    // MARK: - Public Properties

    private let bounds: ClosedRange<Double>
    private let disableOffset: Bool
    private let frameWidth: CGFloat
    private let actionWidth: CGFloat
    @ViewBuilder
    private var frameView: () -> T
    @ViewBuilder
    private var actionView: () -> A
    private let onChange: () -> Void

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let sliderViewYCenter = proxy.size.height / 2
            let sliderPositionX = proxy.size.width / 2 + frameWidth / 2 + (disableOffset ? 0 : offset)
            ZStack {
                frameView()
                    .frame(width: frameWidth, height: proxy.size.height - 5)
                    .position(x: sliderPositionX - actionWidth / 2, y: sliderViewYCenter)
                HStack(spacing: 0) {
                    Capsule()
                        .fill(Theme.sliderThumb)
                        .frame(width: 4, height: proxy.size.height)
                    actionView()
                        .frame(width: actionWidth)
                }
                .opacity(disableOffset ? 0 : 1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())

            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { gesture in
                        isChange = true

                        let translationWidth = gesture.translation.width * 0.5

                        offset = min(0, max(translationWidth, -frameWidth))

                        let newValue =
                            (bounds.upperBound - bounds.lowerBound) * (offset / frameWidth) - bounds.lowerBound

                        value = abs(newValue)

                        onChange()

                    }
                    .onEnded { _ in
                        isChange = false
                    }
            )
            .animation(.easeIn, value: offset)
            .onChange(of: value) { _, _ in
                if !disableOffset {
                    setOffset()
                }
            }
        }
    }

    // MARK: - Initializer

    init(
        value: Binding<Double>,
        bounds: ClosedRange<Double>,
        disableOffset: Bool,
        frameWidth: CGFloat = 65,
        actionWidth: CGFloat = 30,
        @ViewBuilder frameView: @escaping () -> T,
        @ViewBuilder actionView: @escaping () -> A,
        onChange: @escaping () -> Void
    ) {
        self._value = value
        self.bounds = bounds
        self.disableOffset = disableOffset
        self.frameWidth = frameWidth
        self.actionWidth = actionWidth
        self.frameView = frameView
        self.actionView = actionView
        self.onChange = onChange
    }

}

#Preview {
    TimelineSlider(
        value: .constant(0), bounds: 5...34, disableOffset: false,
        frameView: {
            Rectangle()
                .fill(Color.secondary)
        }, actionView: { EmptyView() }, onChange: {}
    )
    .frame(height: 80)
}

extension TimelineSlider {

    // MARK: - Private Methods

    private func setOffset() {
        if !isChange {
            offset = ((-value + bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * frameWidth
        }
    }

}
