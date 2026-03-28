//
//  VideoEditingConfigurationMapper.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 27.03.2026.
//

import Foundation
import SwiftUI
import UIKit

enum VideoEditingConfigurationMapper {

    // MARK: - Public Methods

    static func makeConfiguration(
        from video: Video,
        freeformRect: VideoEditingConfiguration.FreeformRect? = nil,
        selectedAudioTrack: EditorViewModel.AudioTrackSelection = .video,
        selectedTool: ToolEnum? = nil,
        cropTab: VideoEditingConfiguration.CropTab = .rotate,
        currentTimelineTime: Double? = nil
    ) -> VideoEditingConfiguration {
        VideoEditingConfiguration(
            trim: .init(
                lowerBound: video.rangeDuration.lowerBound,
                upperBound: video.rangeDuration.upperBound
            ),
            playback: .init(
                rate: video.rate,
                videoVolume: video.volume,
                currentTimelineTime: currentTimelineTime
            ),
            crop: .init(
                rotationDegrees: video.rotation,
                isMirrored: video.isMirror,
                freeformRect: freeformRect
            ),
            filter: .init(
                filterName: video.filterName,
                brightness: video.colorCorrection.brightness,
                contrast: video.colorCorrection.contrast,
                saturation: video.colorCorrection.saturation
            ),
            frame: .init(
                scaleValue: video.videoFrames?.scaleValue ?? 0,
                colorToken: video.videoFrames.map {
                    SerializedColorCodec.encode($0.frameColor, domain: .frame)
                }
            ),
            audio: .init(
                recordedClip: video.audio.map {
                    .init(
                        url: $0.url,
                        duration: $0.duration,
                        volume: $0.volume
                    )
                },
                selectedTrack: mapSelectedTrack(selectedAudioTrack)
            ),
            textOverlays: video.textBoxes.map {
                .init(
                    id: $0.id,
                    text: $0.text,
                    fontSize: Double($0.fontSize),
                    backgroundColorToken: SerializedColorCodec.encode($0.bgColor, domain: .textBackground),
                    fontColorToken: SerializedColorCodec.encode($0.fontColor, domain: .textForeground),
                    timeRange: .init(
                        lowerBound: $0.timeRange.lowerBound,
                        upperBound: $0.timeRange.upperBound
                    ),
                    offset: .init(
                        x: $0.offset.width,
                        y: $0.offset.height
                    )
                )
            },
            presentation: .init(
                selectedTool: selectedTool,
                cropTab: cropTab
            )
        )
    }

    static func apply(
        _ configuration: VideoEditingConfiguration,
        to video: inout Video
    ) {
        video.rangeDuration = configuration.trim.lowerBound...configuration.trim.upperBound
        video.updateRate(configuration.playback.rate)
        video.setVolume(configuration.playback.videoVolume)
        video.rotation = configuration.crop.rotationDegrees
        video.isMirror = configuration.crop.isMirrored
        video.filterName = configuration.filter.filterName
        video.colorCorrection = ColorCorrection(
            brightness: configuration.filter.brightness,
            contrast: configuration.filter.contrast,
            saturation: configuration.filter.saturation
        )

        if configuration.frame.scaleValue > 0 {
            video.videoFrames = VideoFrames(
                scaleValue: configuration.frame.scaleValue,
                frameColor: SerializedColorCodec.decode(
                    configuration.frame.colorToken,
                    domain: .frame,
                    fallback: Color(uiColor: .systemBackground)
                )
            )
        } else {
            video.videoFrames = nil
        }

        video.audio = configuration.audio.recordedClip.map {
            Audio(
                url: $0.url,
                duration: $0.duration,
                volume: $0.volume
            )
        }

        video.textBoxes = configuration.textOverlays.map {
            TextBox(
                id: $0.id,
                text: $0.text,
                fontSize: CGFloat($0.fontSize),
                lastFontSize: .zero,
                bgColor: SerializedColorCodec.decode(
                    $0.backgroundColorToken,
                    domain: .textBackground,
                    fallback: Color(uiColor: .systemBackground)
                ),
                fontColor: SerializedColorCodec.decode(
                    $0.fontColorToken,
                    domain: .textForeground,
                    fallback: Color(uiColor: .label)
                ),
                timeRange: $0.timeRange.lowerBound...$0.timeRange.upperBound,
                offset: CGSize(
                    width: $0.offset.x,
                    height: $0.offset.y
                ),
                lastOffset: .zero
            )
        }
    }

    static func selectedAudioTrack(
        from configuration: VideoEditingConfiguration
    ) -> EditorViewModel.AudioTrackSelection {
        switch configuration.audio.selectedTrack {
        case .video:
            .video
        case .recorded:
            .recorded
        }
    }

    static func cropTab(
        from configuration: VideoEditingConfiguration
    ) -> EditorViewModel.CropToolTab {
        switch configuration.presentation.cropTab {
        case .format:
            .format
        case .rotate:
            .rotate
        }
    }

    // MARK: - Private Methods

    private static func mapSelectedTrack(
        _ selectedAudioTrack: EditorViewModel.AudioTrackSelection
    ) -> VideoEditingConfiguration.SelectedTrack {
        switch selectedAudioTrack {
        case .video:
            .video
        case .recorded:
            .recorded
        }
    }

}

private enum SerializedColorCodec {

    // MARK: - Public Methods

    static func encode(
        _ color: Color,
        domain: Domain
    ) -> String {
        if let paletteToken = paletteToken(for: color, domain: domain) {
            return "palette:\(paletteToken)"
        }

        return "rgba:\(rgbaHex(for: color))"
    }

    static func decode(
        _ token: String?,
        domain: Domain,
        fallback: Color
    ) -> Color {
        guard let token else { return fallback }

        if token.hasPrefix("palette:") {
            let paletteID = String(token.dropFirst("palette:".count))
            return paletteColor(for: paletteID, domain: domain) ?? fallback
        }

        if token.hasPrefix("rgba:") {
            let rgba = String(token.dropFirst("rgba:".count))
            return color(fromRGBAHex: rgba) ?? fallback
        }

        return fallback
    }

    // MARK: - Private Methods

    private static func paletteToken(
        for color: Color,
        domain: Domain
    ) -> String? {
        domain.options.first(where: { SystemColorPalette.matches($0.color, color) })?.id
    }

    private static func paletteColor(
        for paletteID: String,
        domain: Domain
    ) -> Color? {
        domain.options.first(where: { $0.id == paletteID })?.color
    }

    private static func rgbaHex(
        for color: Color
    ) -> String {
        let resolvedColor = UIColor(color).resolvedColor(
            with: UITraitCollection(userInterfaceStyle: .light)
        )

        guard let components = resolvedColor.cgColor.components else {
            return "FFFFFFFF"
        }

        let rgbaComponents: [CGFloat]

        switch components.count {
        case 2:
            rgbaComponents = [components[0], components[0], components[0], components[1]]
        case 4:
            rgbaComponents = components
        default:
            return "FFFFFFFF"
        }

        return
            rgbaComponents
            .map { component in
                let value = Int(round(component * 255))
                return String(format: "%02X", value)
            }
            .joined()
    }

    private static func color(
        fromRGBAHex rgbaHex: String
    ) -> Color? {
        guard rgbaHex.count == 8 else { return nil }

        let scanner = Scanner(string: rgbaHex)
        var rawValue: UInt64 = 0

        guard scanner.scanHexInt64(&rawValue) else { return nil }

        let red = CGFloat((rawValue & 0xFF00_0000) >> 24) / 255
        let green = CGFloat((rawValue & 0x00FF_0000) >> 16) / 255
        let blue = CGFloat((rawValue & 0x0000_FF00) >> 8) / 255
        let alpha = CGFloat(rawValue & 0x0000_00FF) / 255

        return Color(
            uiColor: UIColor(
                red: red,
                green: green,
                blue: blue,
                alpha: alpha
            )
        )
    }

}

extension SerializedColorCodec {

    fileprivate enum Domain {
        case textBackground
        case textForeground
        case frame

        var options: [SystemColorOption] {
            switch self {
            case .textBackground:
                SystemColorPalette.textBackgrounds
            case .textForeground:
                SystemColorPalette.textForegrounds
            case .frame:
                SystemColorPalette.frameColors
            }
        }
    }

}
