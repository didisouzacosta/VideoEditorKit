//
//  ToolButtonView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct ToolButtonView: View {
    let label: String
    let image: String
    let isChange: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: image)
                    .font(.headline.weight(.semibold))
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 85)
            .foregroundStyle(IOS26Theme.primaryText)
            .overlay(alignment: .topTrailing) {
                if isChange {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(IOS26Theme.primaryText)
                        .padding(8)
                }
            }
            .ios26Card(
                cornerRadius: 20, prominent: isChange,
                tint: isChange ? IOS26Theme.accent : IOS26Theme.accentSecondary)
        }
        .buttonStyle(.plain)
    }
}

struct ToolButtonView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ToolButtonView(label: "Cut", image: "scissors", isChange: false) {}
            ToolButtonView(label: "Cut", image: "scissors", isChange: true) {}

        }
        .frame(width: 100)
    }
}
