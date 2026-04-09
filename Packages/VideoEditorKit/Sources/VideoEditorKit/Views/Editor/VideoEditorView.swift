import SwiftUI

public struct VideoEditorView: View {

    // MARK: - Public Properties

    public typealias SaveState = VideoEditorSaveState
    public typealias Session = VideoEditorSession
    public typealias Callbacks = VideoEditorCallbacks
    public typealias Configuration = VideoEditorConfiguration

    // MARK: - Body

    public var body: some View {
        HostedVideoEditorView(
            title,
            session: session,
            configuration: configuration,
            callbacks: callbacks
        )
    }

    // MARK: - Private Properties

    private let title: String?
    private let session: Session
    private let configuration: Configuration
    private let callbacks: Callbacks

    // MARK: - Initializer

    public init(
        _ title: String? = nil,
        session: Session,
        configuration: Configuration = .init(),
        callbacks: Callbacks = .init()
    ) {
        self.title = title
        self.session = session
        self.configuration = configuration
        self.callbacks = callbacks
    }

    public init(
        _ title: String? = nil,
        source: Session.Source? = nil,
        editingConfiguration: VideoEditingConfiguration? = nil,
        configuration: Configuration = .init(),
        onSaveStateChanged: @escaping (SaveState) -> Void = { _ in },
        onSourceVideoResolved: @escaping (URL) -> Void = { _ in },
        onDismissed: @escaping (VideoEditingConfiguration?) -> Void = { _ in },
        onExportedVideoURL: @escaping (URL) -> Void = { _ in }
    ) {
        self.init(
            title,
            session: .init(
                source: source,
                editingConfiguration: editingConfiguration
            ),
            configuration: configuration,
            callbacks: .init(
                onSaveStateChanged: onSaveStateChanged,
                onSourceVideoResolved: onSourceVideoResolved,
                onDismissed: onDismissed,
                onExportedVideoURL: onExportedVideoURL
            )
        )
    }

    public init(
        _ title: String? = nil,
        sourceVideoURL: URL?,
        editingConfiguration: VideoEditingConfiguration? = nil,
        configuration: Configuration = .init(),
        onSaveStateChanged: @escaping (SaveState) -> Void = { _ in },
        onSourceVideoResolved: @escaping (URL) -> Void = { _ in },
        onDismissed: @escaping (VideoEditingConfiguration?) -> Void = { _ in },
        onExportedVideoURL: @escaping (URL) -> Void = { _ in }
    ) {
        self.init(
            title,
            source: sourceVideoURL.map { .fileURL($0) },
            editingConfiguration: editingConfiguration,
            configuration: configuration,
            onSaveStateChanged: onSaveStateChanged,
            onSourceVideoResolved: onSourceVideoResolved,
            onDismissed: onDismissed,
            onExportedVideoURL: onExportedVideoURL
        )
    }

}

#Preview {
    VideoEditorView(
        "Preview",
        session: VideoEditorSession(source: nil)
    )
}
