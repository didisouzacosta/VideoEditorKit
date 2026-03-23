import PhotosUI
import SwiftUI

struct ExampleVideoImportView: View {
    @Binding var selectedItem: PhotosPickerItem?

    let isImporting: Bool
    let errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerCard
                importButton

                if isImporting {
                    progressCard
                }

                if let errorMessage {
                    messageCard(
                        title: "Import Error",
                        message: errorMessage,
                        tint: Color(red: 0.78, green: 0.25, blue: 0.24)
                    )
                }

                messageCard(
                    title: "How It Works",
                    message: "The selected file is copied into the app sandbox before the editor opens. This keeps the example flow close to a real host app integration.",
                    tint: Color(red: 0.24, green: 0.5, blue: 0.84)
                )
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.11),
                    Color(red: 0.03, green: 0.03, blue: 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

private extension ExampleVideoImportView {
    var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import a video from the device to start editing.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("This example host app loads a real asset first, then opens `VideoEditorView` with real duration, size, and transform metadata.")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.74))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.06), in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    var importButton: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .videos,
            preferredItemEncoding: .current
        ) {
            Label("Choose Video", systemImage: "film.stack")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.26, green: 0.52, blue: 0.86),
                            Color(red: 0.17, green: 0.38, blue: 0.74)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .rect(cornerRadius: 20)
                )
                .foregroundStyle(.white)
        }
        .disabled(isImporting)
        .opacity(isImporting ? 0.65 : 1)
    }

    var progressCard: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text("Preparing Editor")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Copying the selected asset and loading AVFoundation metadata.")
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.72))
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color.white.opacity(0.06), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    func messageCard(
        title: String,
        message: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(tint.opacity(0.14), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.34), lineWidth: 1)
        }
    }
}

#Preview("Idle") {
    ExampleVideoImportViewPreviewHost()
}

#Preview("Importing") {
    ExampleVideoImportViewPreviewHost(
        isImporting: true,
        errorMessage: nil
    )
}

#Preview("Error") {
    ExampleVideoImportViewPreviewHost(
        isImporting: false,
        errorMessage: "The selected video could not be copied into the app sandbox."
    )
}

private struct ExampleVideoImportViewPreviewHost: View {
    @State private var selectedItem: PhotosPickerItem?

    let isImporting: Bool
    let errorMessage: String?

    init(
        isImporting: Bool = false,
        errorMessage: String? = nil
    ) {
        self.isImporting = isImporting
        self.errorMessage = errorMessage
    }

    var body: some View {
        ExampleVideoImportView(
            selectedItem: $selectedItem,
            isImporting: isImporting,
            errorMessage: errorMessage
        )
    }
}
