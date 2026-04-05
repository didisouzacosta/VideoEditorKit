import Foundation
import Testing

@testable import VideoEditorKit

@Suite("URLSessionModelDownloaderTests")
struct URLSessionModelDownloaderTests {

    // MARK: - Public Methods

    @Test
    func downloaderWritesTheDownloadedModelAndReportsCompletionProgress() async throws {
        let remoteURL = try #require(
            URL(string: "https://example.com/base-success.bin")
        )
        let session = makeSession(
            for: remoteURL
        ) { _ in
            let response = HTTPURLResponse(
                url: remoteURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )

            return (response, Data([1, 2, 3, 4]))
        }

        let downloader = URLSessionModelDownloader(
            session: session
        )
        let temporaryURL = makeTemporaryFileURL()
        let reportedProgress = LockedProgressRecorder()

        try await downloader.downloadModel(
            from: remoteURL,
            to: temporaryURL
        ) {
            reportedProgress.append($0)
        }

        let data = try Data(contentsOf: temporaryURL)

        #expect(data == Data([1, 2, 3, 4]))
        #expect(reportedProgress.snapshot() == [0, 1])
    }

    @Test
    func downloaderMapsNonSuccessfulHTTPResponsesToTypedErrors() async throws {
        let remoteURL = try #require(
            URL(string: "https://example.com/base-missing.bin")
        )
        let session = makeSession(
            for: remoteURL
        ) { _ in
            let response = HTTPURLResponse(
                url: remoteURL,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )

            return (response, Data())
        }

        let downloader = URLSessionModelDownloader(
            session: session
        )

        await #expect(throws: TranscriptionError.self) {
            try await downloader.downloadModel(
                from: remoteURL,
                to: makeTemporaryFileURL()
            ) { _ in
            }
        }
    }

    // MARK: - Private Methods

    private func makeSession(
        for remoteURL: URL,
        handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse?, Data)
    ) -> URLSession {
        TranscriptionKitURLProtocol.registry.register(
            handler,
            for: remoteURL
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TranscriptionKitURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeTemporaryFileURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bin")
    }

}

private final class TranscriptionKitURLProtocol: URLProtocol, @unchecked Sendable {

    // MARK: - Private Properties

    static let registry = URLProtocolHandlerRegistry()

    // MARK: - Public Methods

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard
            let requestURL = request.url,
            let handler = Self.registry.handler(
                for: requestURL
            )
        else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badServerResponse)
            )
            return
        }

        do {
            let (response, data) = try handler(request)

            if let response {
                client?.urlProtocol(
                    self,
                    didReceive: response,
                    cacheStoragePolicy: .notAllowed
                )
            }

            client?.urlProtocol(
                self,
                didLoad: data
            )
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(
                self,
                didFailWithError: error
            )
        }
    }

    override func stopLoading() {}

}

private final class URLProtocolHandlerRegistry: @unchecked Sendable {

    // MARK: - Private Properties

    private var handlers: [String: @Sendable (URLRequest) throws -> (HTTPURLResponse?, Data)] = [:]
    private let lock = NSLock()

    // MARK: - Public Methods

    func register(
        _ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse?, Data),
        for remoteURL: URL
    ) {
        lock.lock()
        handlers[remoteURL.absoluteString] = handler
        lock.unlock()
    }

    func handler(
        for remoteURL: URL
    ) -> ((@Sendable (URLRequest) throws -> (HTTPURLResponse?, Data)))? {
        lock.lock()
        let handler = handlers[remoteURL.absoluteString]
        lock.unlock()
        return handler
    }

}

private final class LockedProgressRecorder: @unchecked Sendable {

    // MARK: - Private Properties

    private var values: [Double?] = []
    private let lock = NSLock()

    // MARK: - Public Methods

    func append(_ value: Double?) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func snapshot() -> [Double?] {
        lock.lock()
        let snapshot = values
        lock.unlock()
        return snapshot
    }

}
