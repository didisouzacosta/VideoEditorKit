import CoreGraphics
import Foundation
import UIKit

struct SnapshotCoder: VideoProjectSnapshotCoding {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.encoder = encoder
        self.decoder = decoder
    }

    func makeSnapshot(from project: VideoProject) throws -> VideoProjectSnapshot {
        guard project.sourceVideoURL.isFileURL else {
            throw VideoEditorError.snapshotEncodingFailed
        }

        let sourceVideoPath = project.sourceVideoURL.path
        guard sourceVideoPath.isEmpty == false else {
            throw VideoEditorError.snapshotEncodingFailed
        }

        try validateRuntimeRange(project.selectedTimeRange)

        let captionSnapshots = try project.captions.map(makeCaptionSnapshot)

        return VideoProjectSnapshot(
            sourceVideoPath: sourceVideoPath,
            captions: captionSnapshots,
            preset: ExportPresetSnapshot(project.preset),
            gravity: VideoGravitySnapshot(project.gravity),
            selectedTimeRange: project.selectedTimeRange
        )
    }

    func makeProject(from snapshot: VideoProjectSnapshot) throws -> VideoProject {
        do {
            try validateSnapshot(snapshot)

            let captions = try snapshot.captions.map(makeRuntimeCaption)

            return VideoProject(
                sourceVideoURL: URL(fileURLWithPath: snapshot.sourceVideoPath),
                captions: captions,
                preset: snapshot.preset.runtimeValue,
                gravity: snapshot.gravity.runtimeValue,
                selectedTimeRange: snapshot.selectedTimeRange
            )
        } catch let error as VideoEditorError {
            throw error
        } catch {
            throw VideoEditorError.snapshotDecodingFailed
        }
    }

    func encode(_ project: VideoProject) throws -> Data {
        let snapshot = try makeSnapshot(from: project)
        return try encode(snapshot: snapshot)
    }

    func decodeProject(from data: Data) throws -> VideoProject {
        let snapshot = try decodeSnapshot(from: data)
        return try makeProject(from: snapshot)
    }

    func encode(snapshot: VideoProjectSnapshot) throws -> Data {
        do {
            return try encoder.encode(snapshot)
        } catch {
            throw VideoEditorError.snapshotEncodingFailed
        }
    }

    func decodeSnapshot(from data: Data) throws -> VideoProjectSnapshot {
        do {
            return try decoder.decode(VideoProjectSnapshot.self, from: data)
        } catch {
            throw VideoEditorError.snapshotDecodingFailed
        }
    }
}

private extension SnapshotCoder {
    func makeCaptionSnapshot(from caption: Caption) throws -> CaptionSnapshot {
        try validateRuntimeCaption(caption)

        return CaptionSnapshot(
            id: caption.id,
            text: caption.text,
            startTime: caption.startTime,
            endTime: caption.endTime,
            position: CaptionPositionSnapshot(
                mode: CaptionPlacementModeSnapshot(caption.placementMode),
                normalizedX: Double(caption.position.x),
                normalizedY: Double(caption.position.y)
            ),
            style: CaptionStyleSnapshot(
                fontName: caption.style.fontName,
                fontSize: Double(caption.style.fontSize),
                textColorHex: try hexString(from: caption.style.textColor),
                backgroundColorHex: try caption.style.backgroundColor.map(hexString(from:)),
                padding: Double(caption.style.padding),
                cornerRadius: Double(caption.style.cornerRadius)
            )
        )
    }

    func makeRuntimeCaption(from snapshot: CaptionSnapshot) throws -> Caption {
        Caption(
            id: snapshot.id,
            text: snapshot.text,
            startTime: snapshot.startTime,
            endTime: snapshot.endTime,
            position: CGPoint(
                x: snapshot.position.normalizedX,
                y: snapshot.position.normalizedY
            ),
            placementMode: snapshot.position.mode.runtimeValue,
            style: CaptionStyle(
                fontName: snapshot.style.fontName,
                fontSize: CGFloat(snapshot.style.fontSize),
                textColor: try color(from: snapshot.style.textColorHex),
                backgroundColor: try snapshot.style.backgroundColorHex.map(color(from:)),
                padding: CGFloat(snapshot.style.padding),
                cornerRadius: CGFloat(snapshot.style.cornerRadius)
            )
        )
    }

    func validateSnapshot(_ snapshot: VideoProjectSnapshot) throws {
        guard snapshot.sourceVideoPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw VideoEditorError.snapshotDecodingFailed
        }

        try validateSnapshotRange(snapshot.selectedTimeRange)

        for caption in snapshot.captions {
            try validateSnapshotCaption(caption)
        }
    }

    func validateRuntimeCaption(_ caption: Caption) throws {
        guard caption.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw VideoEditorError.snapshotEncodingFailed
        }

        guard caption.startTime.isFinite, caption.endTime.isFinite, caption.startTime < caption.endTime else {
            throw VideoEditorError.snapshotEncodingFailed
        }

        try validateNormalizedCoordinate(Double(caption.position.x), encodingError: .snapshotEncodingFailed)
        try validateNormalizedCoordinate(Double(caption.position.y), encodingError: .snapshotEncodingFailed)

        guard caption.style.fontName.isEmpty == false else {
            throw VideoEditorError.snapshotEncodingFailed
        }

        try validateNonNegativeMetric(Double(caption.style.fontSize), encodingError: .snapshotEncodingFailed)
        try validateNonNegativeMetric(Double(caption.style.padding), encodingError: .snapshotEncodingFailed)
        try validateNonNegativeMetric(Double(caption.style.cornerRadius), encodingError: .snapshotEncodingFailed)
    }

    func validateSnapshotCaption(_ caption: CaptionSnapshot) throws {
        guard caption.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw VideoEditorError.snapshotDecodingFailed
        }

        guard caption.startTime.isFinite, caption.endTime.isFinite, caption.startTime < caption.endTime else {
            throw VideoEditorError.snapshotDecodingFailed
        }

        try validateNormalizedCoordinate(caption.position.normalizedX, encodingError: .snapshotDecodingFailed)
        try validateNormalizedCoordinate(caption.position.normalizedY, encodingError: .snapshotDecodingFailed)

        guard caption.style.fontName.isEmpty == false else {
            throw VideoEditorError.snapshotDecodingFailed
        }

        try validateNonNegativeMetric(caption.style.fontSize, encodingError: .snapshotDecodingFailed)
        try validateNonNegativeMetric(caption.style.padding, encodingError: .snapshotDecodingFailed)
        try validateNonNegativeMetric(caption.style.cornerRadius, encodingError: .snapshotDecodingFailed)

        _ = try color(from: caption.style.textColorHex)
        _ = try caption.style.backgroundColorHex.map(color(from:))
    }

    func validateRuntimeRange(_ range: ClosedRange<Double>) throws {
        guard range.lowerBound.isFinite, range.upperBound.isFinite, range.lowerBound <= range.upperBound else {
            throw VideoEditorError.snapshotEncodingFailed
        }
    }

    func validateSnapshotRange(_ range: ClosedRange<Double>) throws {
        guard range.lowerBound.isFinite, range.upperBound.isFinite, range.lowerBound <= range.upperBound else {
            throw VideoEditorError.snapshotDecodingFailed
        }
    }

    func validateNormalizedCoordinate(
        _ value: Double,
        encodingError: VideoEditorError
    ) throws {
        guard value.isFinite, (0...1).contains(value) else {
            throw encodingError
        }
    }

    func validateNonNegativeMetric(
        _ value: Double,
        encodingError: VideoEditorError
    ) throws {
        guard value.isFinite, value >= 0 else {
            throw encodingError
        }
    }

    func hexString(from color: UIColor) throws -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        let resolvedColor = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        guard resolvedColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            throw VideoEditorError.snapshotEncodingFailed
        }

        let rgba = [red, green, blue, alpha].map { component in
            Int((component * 255).rounded())
        }

        return String(
            format: "%02X%02X%02X%02X",
            rgba[0],
            rgba[1],
            rgba[2],
            rgba[3]
        )
    }

    func color(from hex: String) throws -> UIColor {
        let normalizedHex = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()

        guard normalizedHex.count == 6 || normalizedHex.count == 8,
              let value = UInt64(normalizedHex, radix: 16) else {
            throw VideoEditorError.snapshotDecodingFailed
        }

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        if normalizedHex.count == 6 {
            red = CGFloat((value >> 16) & 0xFF) / 255
            green = CGFloat((value >> 8) & 0xFF) / 255
            blue = CGFloat(value & 0xFF) / 255
            alpha = 1
        } else {
            red = CGFloat((value >> 24) & 0xFF) / 255
            green = CGFloat((value >> 16) & 0xFF) / 255
            blue = CGFloat((value >> 8) & 0xFF) / 255
            alpha = CGFloat(value & 0xFF) / 255
        }

        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

private extension ExportPresetSnapshot {
    init(_ preset: ExportPreset) {
        switch preset {
        case .original:
            self = .original
        case .instagram:
            self = .instagram
        case .youtube:
            self = .youtube
        case .tiktok:
            self = .tiktok
        }
    }

    var runtimeValue: ExportPreset {
        switch self {
        case .original:
            .original
        case .instagram:
            .instagram
        case .youtube:
            .youtube
        case .tiktok:
            .tiktok
        }
    }
}

private extension VideoGravitySnapshot {
    init(_ gravity: VideoGravity) {
        switch gravity {
        case .fit:
            self = .fit
        case .fill:
            self = .fill
        }
    }

    var runtimeValue: VideoGravity {
        switch self {
        case .fit:
            .fit
        case .fill:
            .fill
        }
    }
}

private extension CaptionPlacementPresetSnapshot {
    init(_ preset: CaptionPlacementPreset) {
        switch preset {
        case .top:
            self = .top
        case .middle:
            self = .middle
        case .bottom:
            self = .bottom
        }
    }

    var runtimeValue: CaptionPlacementPreset {
        switch self {
        case .top:
            .top
        case .middle:
            .middle
        case .bottom:
            .bottom
        }
    }
}

private extension CaptionPlacementModeSnapshot {
    init(_ mode: CaptionPlacementMode) {
        switch mode {
        case .freeform:
            self = .freeform
        case .preset(let preset):
            self = .preset(CaptionPlacementPresetSnapshot(preset))
        }
    }

    var runtimeValue: CaptionPlacementMode {
        switch self {
        case .freeform:
            .freeform
        case .preset(let preset):
            .preset(preset.runtimeValue)
        }
    }
}
