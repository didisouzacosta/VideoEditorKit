//
//  Video.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVKit
import SwiftUI

struct Video: Identifiable, @unchecked Sendable {

    // MARK: - Public Properties

    var id: UUID = UUID()
    var url: URL
    var asset: AVAsset
    let originalDuration: Double
    var rangeDuration: ClosedRange<Double>
    var thumbnailsImages = [ThumbnailImage]()
    var rate: Float = 1.0
    var rotation: Double = 0
    var presentationSize: CGSize = .zero
    var frameSize: CGSize = .zero
    var geometrySize: CGSize = .zero
    var isMirror: Bool = false
    var toolsApplied = [Int]()
    var filterName: String? = nil
    var colorCorrection = ColorCorrection()
    var videoFrames: VideoFrames? = nil
    var textBoxes: [TextBox] = []
    var audio: Audio?
    var volume: Float = 1.0
    var totalDuration: Double {
        rangeDuration.upperBound - rangeDuration.lowerBound
    }

    @MainActor
    static let mock: Video = .init(
        url: URL(string: "https://www.google.com/")!, rangeDuration: 0...250)

    static func load(from url: URL) async -> Video {
        let asset = AVURLAsset(url: url)
        let duration = (try? await asset.load(.duration).seconds) ?? .zero
        let resolvedDuration = duration.isFinite ? duration : .zero
        let presentationSize = await asset.presentationSize() ?? .zero
        return Video(
            url: url, asset: asset, originalDuration: resolvedDuration,
            rangeDuration: .zero...resolvedDuration,
            presentationSize: presentationSize)
    }

    init(
        url: URL,
        asset: AVAsset,
        originalDuration: Double,
        rangeDuration: ClosedRange<Double>,
        rate: Float = 1.0,
        rotation: Double = 0,
        presentationSize: CGSize = .zero
    ) {
        self.url = url
        self.asset = asset
        self.originalDuration = originalDuration
        self.rangeDuration = rangeDuration
        self.rate = rate
        self.rotation = rotation
        self.presentationSize = presentationSize
    }

    init(url: URL) {
        let asset = AVURLAsset(url: url)
        self.init(url: url, asset: asset, originalDuration: .zero, rangeDuration: .zero ... .zero)
    }

    init(url: URL, rangeDuration: ClosedRange<Double>, rate: Float = 1.0, rotation: Double = 0) {
        let asset = AVURLAsset(url: url)
        let originalDuration = max(rangeDuration.upperBound, .zero)
        self.init(
            url: url, asset: asset, originalDuration: originalDuration, rangeDuration: rangeDuration,
            rate: rate, rotation: rotation)
    }

    func makeThumbnails(containerSize: CGSize) async -> [ThumbnailImage] {
        let imagesCount = thumbnailCount(for: containerSize)
        guard imagesCount > 0 else { return [] }

        var thumbnails = [ThumbnailImage]()
        thumbnails.reserveCapacity(imagesCount)

        for index in 0..<imagesCount {
            let offset = Double(index) * (originalDuration / Double(imagesCount))
            let thumbnailImage = ThumbnailImage(image: await asset.generateImage(at: offset))
            thumbnails.append(thumbnailImage)
        }

        return thumbnails
    }

    ///reset and update

    func isAppliedTool(for tool: ToolEnum) -> Bool {
        toolsApplied.contains(tool.rawValue)
    }

    func thumbnailCount(for containerSize: CGSize) -> Int {
        let usableWidth = max(containerSize.width - 32, 1)
        let count = Int(ceil(usableWidth / Double(70 / 1.5)))

        return max(count, 1)
    }

    // MARK: - Public Methods

    mutating func updateRate(_ rate: Float) {

        let lowerBound = (rangeDuration.lowerBound * Double(self.rate)) / Double(rate)
        let upperBound = (rangeDuration.upperBound * Double(self.rate)) / Double(rate)
        rangeDuration = lowerBound...upperBound

        self.rate = rate
    }

    mutating func resetRangeDuration() {
        self.rangeDuration = 0...originalDuration
    }

    mutating func resetRate() {
        updateRate(1.0)
    }

    mutating func rotate() {
        rotation = rotation.nextAngle()
    }

    mutating func appliedTool(for tool: ToolEnum) {
        if !isAppliedTool(for: tool) {
            toolsApplied.append(tool.rawValue)
        }
    }

    mutating func setVolume(_ value: Float) {
        volume = value
    }

    mutating func removeTool(for tool: ToolEnum) {
        if isAppliedTool(for: tool) {
            toolsApplied.removeAll(where: { $0 == tool.rawValue })
        }
    }

    mutating func setFilter(_ filter: String?) {
        filterName = filter
    }

}

extension Video: Equatable {

    // MARK: - Public Methods

    static func == (lhs: Video, rhs: Video) -> Bool {
        lhs.id == rhs.id
    }

}

extension Double {

    // MARK: - Public Methods

    func nextAngle() -> Double {
        var next = Int(self) + 90
        if next >= 360 {
            next = 0
        } else if next < 0 {
            next = 360 - abs(next % 360)
        }
        return Double(next)
    }

}

struct ThumbnailImage: Identifiable {

    // MARK: - Public Properties

    var id: UUID = UUID()
    var image: UIImage?

    // MARK: - Initializer

    init(image: UIImage? = nil) {
        self.image = image?.resize(to: .init(width: 250, height: 350))
    }

}

struct VideoFrames {

    // MARK: - Public Properties

    var scaleValue: Double = 0
    var frameColor: Color = Color(uiColor: .systemBackground)
    var scale: Double {
        1 - scaleValue
    }

    var isActive: Bool {
        scaleValue > 0
    }

    // MARK: - Public Methods

    mutating func reset() {
        scaleValue = 0
        frameColor = Color(uiColor: .systemBackground)
    }

}
