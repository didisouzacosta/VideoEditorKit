//
//  ThumbnailsSliderView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVKit
import SwiftUI

struct ThumbnailsSliderView: View {
    @State var rangeDuration: ClosedRange<Double> = 0...1
    @Binding var currentTime: Double
    @Binding var video: Video?
    var isChangeState: Bool?
    let onChangeTimeValue: () -> Void

    private var totalDuration: Double {
        rangeDuration.upperBound - rangeDuration.lowerBound
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(totalDuration.formatterTimeString())
                .font(.subheadline)

            GeometryReader { proxy in
                ZStack {
                    thumbnailsImagesSection(proxy)

                    if let video {
                        RangedSliderView(
                            value: $rangeDuration,
                            bounds: 0...video.originalDuration,
                            onEndChange: { setOnChangeTrim(false) }
                        ) {
                            Rectangle().blendMode(.destinationOut)
                        }
                        .onChange(of: self.video?.rangeDuration.upperBound) { _, upperBound in
                            if let upperBound {
                                currentTime = Double(upperBound)
                                onChangeTimeValue()
                                setOnChangeTrim(true)
                            }
                        }
                        .onChange(of: self.video?.rangeDuration.lowerBound) { _, lowerBound in
                            if let lowerBound {
                                currentTime = Double(lowerBound)
                                onChangeTimeValue()
                                setOnChangeTrim(true)
                            }
                        }
                        .onChange(of: rangeDuration) { _, newValue in
                            self.video?.rangeDuration = newValue
                        }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .onAppear {
                    setVideoRange()
                }
            }
            .frame(height: 70)
        }
        .onChange(of: isChangeState) { _, isChange in
            if !(isChange ?? true) {
                setVideoRange()
            }
        }
    }
}

struct ThumbnailsSliderView_Previews: PreviewProvider {
    static var previews: some View {
        ThumbnailsSliderView(
            currentTime: .constant(0),
            video: .constant(Video.mock),
            isChangeState: nil,
            onChangeTimeValue: {}
        )
    }
}

extension ThumbnailsSliderView {
    private func setVideoRange() {
        if let video {
            rangeDuration = video.rangeDuration
        }
    }

    @ViewBuilder
    private func thumbnailsImagesSection(_ proxy: GeometryProxy) -> some View {
        if let video {
            HStack(spacing: 0) {
                ForEach(video.thumbnailsImages) { trimData in
                    if let image = trimData.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(
                                width: proxy.size.width / CGFloat(video.thumbnailsImages.count),
                                height: proxy.size.height - 5
                            )
                            .clipped()
                    }
                }
            }
        }
    }

    private func setOnChangeTrim(_ isChange: Bool) {
        if !isChange {
            currentTime = video?.rangeDuration.upperBound ?? 0
            onChangeTimeValue()
        }
    }
}
