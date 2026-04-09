//
//  HostedVideoEditorPlayerTrailingControlsView.swift
//  VideoEditorKit
//
//  Created by Codex on 09.04.2026.
//

import SwiftUI

@MainActor
struct HostedVideoEditorPlayerTrailingControlsView: View {

    private enum Constants {
        static let settleAnimation = Animation.smooth(
            duration: 0.28,
            extraBounce: 0.04
        )
    }

    // MARK: - Public Properties

    let shouldShowResetButton: Bool
    let onReset: () -> Void

    // MARK: - Body

    var body: some View {
        content
    }

    // MARK: - Private Properties

    @ViewBuilder
    private var content: some View {
        if shouldShowResetButton {
            Button {
                withAnimation(Constants.settleAnimation) {
                    onReset()
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(14)
                    .circleControl(
                        prominent: true,
                        tint: .black.opacity(0.82)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset transform")
        } else {
            EmptyView()
        }
    }

}

#Preview("Visible") {
    HostedVideoEditorPlayerTrailingControlsView(
        shouldShowResetButton: true,
        onReset: {}
    )
    .padding()
    .background(.gray)
}

#Preview("Hidden") {
    HostedVideoEditorPlayerTrailingControlsView(
        shouldShowResetButton: false,
        onReset: {}
    )
}
