import AVKit
import SwiftUI

struct SavedVideoPreviewScreen: View {

    // MARK: - Environments

    @Environment(\.dismiss) private var dismiss

    // MARK: - States

    @State private var player: AVPlayer

    // MARK: - Public Properties

    let url: URL

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VideoPlayer(player: player)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(ExampleStrings.projectPreview)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(ExampleStrings.close, action: dismiss.callAsFunction)
                    }
                }
        }
    }

    // MARK: - Initializer

    init(url: URL) {
        self.url = url

        _player = State(initialValue: AVPlayer(url: url))
    }

}

#Preview {
    SavedVideoPreviewScreen(
        url: URL(fileURLWithPath: "/tmp/preview.mp4")
    )
}
