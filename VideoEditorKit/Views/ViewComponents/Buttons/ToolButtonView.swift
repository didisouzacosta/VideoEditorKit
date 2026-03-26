//
//  ToolButtonView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct ToolButtonView: View {

    // MARK: - Public Properties

    let label: String
    let image: String
    let isChange: Bool
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: image)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.primary)
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 85)
            .overlay(alignment: .topTrailing) {
                if isChange {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.primary)
                        .padding(8)
                }
            }
            .card(
                cornerRadius: 20, prominent: isChange,
                tint: isChange ? Theme.accent : Theme.secondary)
        }
        .buttonStyle(.plain)
    }

}

#Preview {
    VStack {
        ToolButtonView(label: "Cut", image: "scissors", isChange: false) {}
        ToolButtonView(label: "Cut", image: "scissors", isChange: true) {}
    }
    .frame(width: 100)
}
