#if os(iOS)
    import Foundation

    public struct VideoEditorImportedFileSource: Sendable, Equatable {

        // MARK: - Public Properties

        public let taskIdentifier: String

        // MARK: - Private Properties

        private let resolver: @Sendable () async throws -> URL

        // MARK: - Initializer

        public init(
            taskIdentifier: String,
            resolveURL resolver: @escaping @Sendable () async throws -> URL
        ) {
            self.taskIdentifier = taskIdentifier
            self.resolver = resolver
        }

        // MARK: - Public Methods

        public func resolveURL() async throws -> URL {
            try await resolver()
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.taskIdentifier == rhs.taskIdentifier
        }

    }

    public enum VideoEditorSessionSource: Sendable, Equatable {

        case fileURL(URL)
        case importedFile(VideoEditorImportedFileSource)

        // MARK: - Public Properties

        public var fileURL: URL? {
            switch self {
            case .fileURL(let url):
                url
            case .importedFile:
                nil
            }
        }

        public var taskIdentifier: String {
            switch self {
            case .fileURL(let url):
                "file:\(url.absoluteString)"
            case .importedFile(let source):
                "imported:\(source.taskIdentifier)"
            }
        }

        // MARK: - Public Methods

        public func resolveURL() async throws -> URL {
            switch self {
            case .fileURL(let url):
                url
            case .importedFile(let source):
                try await source.resolveURL()
            }
        }

    }

#endif
