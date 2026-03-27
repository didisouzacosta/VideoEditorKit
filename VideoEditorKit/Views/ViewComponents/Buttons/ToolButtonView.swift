//
//  ToolButtonView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct ToolButtonView: View {

    // MARK: - Private Properties

    private let label: String
    private let image: String
    private let isChange: Bool
    private let action: () -> Void

    // MARK: - Body

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
            .overlay(alignment: .topTrailing) {
                if isChange {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.primary)
                        .padding(8)
                }
            }
            .card(
                cornerRadius: 16,
                prominent: isChange,
                tint: isChange ? Theme.accent : Theme.secondary
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Initializer

    init(_ label: String, image: String, isChange: Bool, action: @escaping () -> Void) {
        self.label = label
        self.image = image
        self.isChange = isChange
        self.action = action
    }

}

#Preview {
    VStack {
        ToolButtonView("Cut", image: "scissors", isChange: false) {}
        ToolButtonView("Cut", image: "scissors", isChange: true) {}
    }
    .frame(width: 100)
}
