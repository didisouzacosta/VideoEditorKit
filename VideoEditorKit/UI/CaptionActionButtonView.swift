import SwiftUI

struct CaptionActionButtonView: View {
    let title: String
    let loadingTitle: String
    let systemImage: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: systemImage)
                }

                Text(isLoading ? loadingTitle : title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(background, in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .foregroundStyle(.white)
    }
}

private extension CaptionActionButtonView {
    var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.2, green: 0.28, blue: 0.42),
                Color(red: 0.11, green: 0.16, blue: 0.27)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var borderColor: Color {
        isDisabled || isLoading ? Color.white.opacity(0.08) : Color.white.opacity(0.18)
    }
}

#Preview("Idle") {
    ZStack {
        Color.black.ignoresSafeArea()
        CaptionActionButtonView(
            title: "Generate",
            loadingTitle: "Generating",
            systemImage: "captions.bubble",
            isLoading: false,
            isDisabled: false,
            action: {}
        )
        .padding()
    }
}

#Preview("Loading") {
    ZStack {
        Color.black.ignoresSafeArea()
        CaptionActionButtonView(
            title: "Translate",
            loadingTitle: "Translating",
            systemImage: "globe",
            isLoading: true,
            isDisabled: false,
            action: {}
        )
        .padding()
    }
}
