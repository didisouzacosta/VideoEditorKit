//
//  NewTimelineSlider.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct TimelineSlider<T: View, A: View>: View {
    @State private var lastOffset: CGFloat = 0
    var bounds: ClosedRange<Double>
    var disableOffset: Bool
    @Binding var value: Double
    @State var isChange: Bool = false
    @State var offset: CGFloat = 0
    @State var gestureW: CGFloat = 0
    var frameWidth: CGFloat = 65
    let actionWidth: CGFloat = 30
    @ViewBuilder
    var frameView: () -> T
    @ViewBuilder
    var actionView: () -> A
    let onChange: () -> Void

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
                        .fill(IOS26Theme.sliderThumb)
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
}

struct NewTimelineSlider_Previews: PreviewProvider {
    @State static var currentTime = 0.0
    static var previews: some View {
        TimelineSlider(
            bounds: 5...34, disableOffset: false, value: $currentTime,
            frameView: {
                Rectangle()
                    .fill(Color.secondary)
            }, actionView: { EmptyView() }, onChange: {}
        )
        .frame(height: 80)
    }
}

extension TimelineSlider {

    private func setOffset() {
        if !isChange {
            offset = ((-value + bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * frameWidth
        }
    }
}
