#if os(iOS)
    import AVFoundation
    import CoreGraphics
    import Foundation

    public struct ExportedVideo: Equatable, Sendable {

        // MARK: - Public Properties

        public let url: URL
        public let width: CGFloat
        public let height: CGFloat
        public let duration: Double
        public let fileSize: Int64

        public var aspectRatio: CGFloat {
            guard width > 0, height > 0 else { return 1 }
            return width / height
        }

        // MARK: - Initializer

        public init(
            _ url: URL,
            width: CGFloat,
            height: CGFloat,
            duration: Double,
            fileSize: Int64
        ) {
            self.url = url
            self.width = width
            self.height = height
            self.duration = duration
            self.fileSize = fileSize
        }

        // MARK: - Public Methods

        public static func load(from url: URL) async -> ExportedVideo {
            let asset = AVURLAsset(url: url)
            let presentationSize = await resolvedPresentationSize(for: asset)
            let duration = (try? await asset.load(.duration).seconds) ?? .zero
            let fileSize = resolvedFileSize(for: url)

            return ExportedVideo(
                url,
                width: max(presentationSize.width, 0),
                height: max(presentationSize.height, 0),
                duration: max(duration, 0),
                fileSize: max(fileSize, 0)
            )
        }

        // MARK: - Private Methods

        private static func resolvedFileSize(for url: URL) -> Int64 {
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path())
            let sizeValue = attributes?[.size] as? NSNumber
            return sizeValue?.int64Value ?? 0
        }

        private static func resolvedPresentationSize(for asset: AVURLAsset) async -> CGSize {
            guard let tracks = try? await asset.loadTracks(withMediaType: .video) else { return .zero }
            guard let track = tracks.first else { return .zero }
            guard let naturalSize = try? await track.load(.naturalSize) else { return .zero }
            guard let preferredTransform = try? await track.load(.preferredTransform) else {
                return naturalSize
            }

            let transformedSize = naturalSize.applying(preferredTransform)
            let resolvedSize = CGSize(
                width: abs(transformedSize.width),
                height: abs(transformedSize.height)
            )

            guard resolvedSize.width > 0, resolvedSize.height > 0 else {
                return naturalSize
            }

            return resolvedSize
        }

    }

#endif
