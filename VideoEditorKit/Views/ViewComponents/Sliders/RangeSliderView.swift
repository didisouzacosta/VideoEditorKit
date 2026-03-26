//
//  RangeSliderView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct RangedSliderView: View {

    // MARK: - Public Properties

    private let currentValue: Binding<ClosedRange<Double>>?
    private let sliderBounds: ClosedRange<Double>
    private let step: Double
    private let onEndChange: (() -> Void)?

    // MARK: - Body

    @ViewBuilder
    var body: some View {
        GeometryReader { geometry in
            sliderView(sliderSize: geometry.size)
        }
    }

    // MARK: - Initializer

    init(
        value: Binding<ClosedRange<Double>>?,
        bounds: ClosedRange<Double>,
        step: Double = 1,
        onEndChange: (() -> Void)?
    ) {
        self.onEndChange = onEndChange
        self.step = step
        self.currentValue = value
        self.sliderBounds = bounds
    }

    // MARK: - Private Methods

    private func sliderView(sliderSize: CGSize) -> some View {
        let trackHeight = max(sliderSize.height, 1)
        let valueRange = currentValue?.wrappedValue ?? sliderBounds
        let leftThumbLocation = position(for: valueRange.lowerBound, width: sliderSize.width)
        let rightThumbLocation = position(for: valueRange.upperBound, width: sliderSize.width)
        let selectedWidth = max(rightThumbLocation - leftThumbLocation, 0)

        return ZStack {
            HStack(spacing: 0) {
                maskedRegion(width: leftThumbLocation, height: trackHeight)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.black.opacity(0.36))
                    .overlay {
                        Rectangle()
                            .strokeBorder(.yellow, lineWidth: 4)
                    }
                    .frame(width: selectedWidth, height: trackHeight)

                maskedRegion(width: max(sliderSize.width - rightThumbLocation, 0), height: trackHeight)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            let leftThumbPoint = CGPoint(x: leftThumbLocation - 4, y: trackHeight / 2)
            let rightThumbPoint = CGPoint(x: rightThumbLocation + 4, y: trackHeight / 2)

            handleView(
                height: trackHeight,
                position: leftThumbPoint,
                isLeftThumb: true
            )
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { dragValue in
                        let xThumbOffset = min(
                            max(0, dragValue.location.x),
                            rightThumbLocation - minimumGap(in: sliderSize.width)
                        )

                        let newLowerBound = value(at: xThumbOffset, width: sliderSize.width)

                        if newLowerBound < currentValue?.wrappedValue.upperBound ?? sliderBounds.upperBound {
                            currentValue?.wrappedValue =
                                newLowerBound...(currentValue?.wrappedValue.upperBound ?? sliderBounds.upperBound)
                        }
                    }
                    .onEnded { _ in
                        onEndChange?()
                    }
            )

            handleView(
                height: trackHeight,
                position: rightThumbPoint,
                isLeftThumb: false
            )
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { dragValue in
                        let xThumbOffset = max(
                            leftThumbLocation + minimumGap(in: sliderSize.width),
                            min(dragValue.location.x, sliderSize.width)
                        )

                        let newUpperBound = value(at: xThumbOffset, width: sliderSize.width)

                        if newUpperBound > currentValue?.wrappedValue.lowerBound ?? sliderBounds.lowerBound {
                            currentValue?.wrappedValue =
                                (currentValue?.wrappedValue.lowerBound ?? sliderBounds.lowerBound)...newUpperBound
                        }
                    }
                    .onEnded { _ in
                        onEndChange?()
                    }
            )
        }
    }

    private func position(for value: Double, width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }

        let totalRange = max(sliderBounds.upperBound - sliderBounds.lowerBound, step)
        let relativeValue = value - sliderBounds.lowerBound
        let progress = relativeValue / totalRange

        return min(max(CGFloat(progress) * width, 0), width)
    }

    private func value(at position: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return sliderBounds.lowerBound }

        let totalRange = max(sliderBounds.upperBound - sliderBounds.lowerBound, step)
        let rawValue = sliderBounds.lowerBound + (Double(position / width) * totalRange)
        let steppedValue = (round(rawValue / step) * step)

        return min(sliderBounds.upperBound, max(sliderBounds.lowerBound, steppedValue))
    }

    private func minimumGap(in width: CGFloat) -> CGFloat {
        let totalRange = max(sliderBounds.upperBound - sliderBounds.lowerBound, step)
        let stepWidth = width / CGFloat(totalRange / step)
        return max(stepWidth, 8)
    }

    private func maskedRegion(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(.black.opacity(0.8))
            .frame(width: max(width, 0), height: height)
    }

    private func handleView(height: CGFloat, position: CGPoint, isLeftThumb: Bool) -> some View {
        let hitSize = CGSize(width: 44, height: max(height + 8, 44))

        return ZStack {
            Rectangle()
                .fill(.yellow)
                .frame(width: 16, height: height)
                .overlay {
                    VStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { _ in
                            Capsule(style: .continuous)
                                .fill(.black)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        cornerRadii: .init(
                            topLeading: isLeftThumb ? 8 : 0,
                            bottomLeading: isLeftThumb ? 8 : 0,
                            bottomTrailing: isLeftThumb ? 0 : 8,
                            topTrailing: isLeftThumb ? 0 : 8
                        )
                    )
                )
        }
        .frame(
            width: hitSize.width,
            height: hitSize.height
        )
        .position(
            x: position.x,
            y: position.y
        )
        .accessibilityLabel(isLeftThumb ? "Trim start" : "Trim end")
    }

}

#Preview {
    RangedSliderView(
        value: .constant(20...60),
        bounds: 1...100,
        onEndChange: {}
    )
    .frame(height: 72)
}
