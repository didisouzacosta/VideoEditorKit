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
    private let isBlocked: Bool
    private let action: () -> Void

    // MARK: - Body

    var body: some View {
        Button {
            action()
        } label: {
            buttonContent
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    // MARK: - Private Properties

    private var buttonContent: some View {
        toolLabel
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isBlocked ? 0.55 : 1)
            .contentShape(Rectangle())
            .overlay(alignment: .topLeading) {
                if isBlocked {
                    blockedBadge
                }
            }
            .overlay(alignment: .topTrailing) {
                if isChange {
                    appliedBadge
                }
            }
            .card(
                cornerRadius: 16,
                prominent: isChange && !isBlocked,
                tint: buttonTint
            )
    }

    private var toolLabel: some View {
        VStack(spacing: 4) {
            Image(systemName: image)
                .font(.headline.weight(.semibold))
            Text(label)
                .font(.caption.weight(.medium))
        }
    }

    private var blockedBadge: some View {
        ZStack {
            Circle()
                .fill(Theme.rootBackground.opacity(0.95))

            Image(systemName: "lock.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.secondary)
        }
        .frame(width: 28, height: 28)
        .padding(8)
    }

    private var appliedBadge: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.primary)
            .padding(8)
    }

    private var buttonTint: Color {
        isBlocked ? Theme.secondary : (isChange ? Theme.accent : Theme.secondary)
    }

    private var accessibilityLabel: String {
        isBlocked ? "\(label), locked" : label
    }

    private var accessibilityValue: String {
        if isBlocked {
            "Unavailable"
        } else if isChange {
            "Applied"
        } else {
            "Available"
        }
    }

    private var accessibilityHint: String {
        isBlocked
            ? "Double-tap to learn how to unlock this tool."
            : "Double-tap to open this editing tool."
    }

    private var accessibilityIdentifier: String {
        "tool-button-\(label.lowercased().replacingOccurrences(of: " ", with: "-"))"
    }

    // MARK: - Initializer

    init(
        _ label: String,
        image: String,
        isChange: Bool,
        isBlocked: Bool = false,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.image = image
        self.isChange = isChange
        self.isBlocked = isBlocked
        self.action = action
    }

}

#Preview {
    VStack {
        ToolButtonView("Cut", image: "scissors", isChange: false) {}
            .frame(width: 100, height: 100)
        ToolButtonView("Cut", image: "scissors", isChange: true) {}
            .frame(width: 100, height: 100)
        ToolButtonView("Cut", image: "scissors", isChange: false, isBlocked: true) {}
            .frame(width: 100, height: 100)
    }
}
