//
//  TranscriptOverlayPreview.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import SwiftUI

@MainActor
struct TranscriptOverlayPreview: View {

    // MARK: - Public Properties

    let segment: EditableTranscriptSegment
    let style: TranscriptStyle?
    let overlayPosition: TranscriptOverlayPosition
    let overlaySize: TranscriptOverlaySize
    let isSelected: Bool
    let containerSize: CGSize
    let onSelect: () -> Void
    let onDismissSelection: () -> Void
    let onSelectPosition: (TranscriptOverlayPosition) -> Void
    let onSelectSize: (TranscriptOverlaySize) -> Void

    // MARK: - Body

    var body: some View {
        let layout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: containerSize.width,
            videoHeight: containerSize.height,
            selectedPosition: overlayPosition,
            selectedSize: overlaySize,
            text: segment.editedText
        )

        ZStack {
            if isSelected {
                Color.black.opacity(0.12)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismissSelection)
            }

            overlayCard(layout: layout)

            if isSelected {
                controls(layout: layout)
            }
        }
        .allFrame()
    }

    // MARK: - Private Properties

    private var resolvedStyle: TranscriptStyle {
        style
            ?? TranscriptStyle(
                id: UUID(),
                name: "Default",
                fontFamily: "SF Pro Rounded"
            )
    }

    private var textAlignment: Alignment {
        switch resolvedStyle.textAlignment {
        case .leading:
            .leading
        case .center:
            .center
        case .trailing:
            .trailing
        }
    }

    // MARK: - Private Methods

    private func overlayCard(
        layout: TranscriptOverlayLayoutResolver.Layout
    ) -> some View {
        ZStack {
            if resolvedStyle.hasStroke, let strokeColor = resolvedStyle.strokeColor {
                strokedText(
                    color: Color(rgba: strokeColor),
                    fontSize: layout.fontSize
                )
            }

            overlayText(fontSize: layout.fontSize)
        }
        .frame(
            width: layout.overlayFrame.width,
            height: layout.overlayFrame.height,
            alignment: textAlignment
        )
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.08) : .clear)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.95), lineWidth: 1.5)
                    }
                }
        )
        .position(
            x: layout.overlayFrame.midX,
            y: layout.overlayFrame.midY
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private func overlayText(fontSize: CGFloat) -> some View {
        Text(segment.editedText)
            .font(.custom(resolvedStyle.fontFamily, size: fontSize))
            .foregroundStyle(Color(rgba: resolvedStyle.textColor))
            .italic(resolvedStyle.isItalic)
            .multilineTextAlignment(multilineAlignment)
            .lineLimit(3)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: textAlignment)
    }

    private func strokedText(
        color: Color,
        fontSize: CGFloat
    ) -> some View {
        ZStack {
            overlayText(fontSize: fontSize)
                .foregroundStyle(color)
                .offset(x: -1, y: 0)
            overlayText(fontSize: fontSize)
                .foregroundStyle(color)
                .offset(x: 1, y: 0)
            overlayText(fontSize: fontSize)
                .foregroundStyle(color)
                .offset(x: 0, y: -1)
            overlayText(fontSize: fontSize)
                .foregroundStyle(color)
                .offset(x: 0, y: 1)
        }
    }

    private func controls(
        layout: TranscriptOverlayLayoutResolver.Layout
    ) -> some View {
        VStack(spacing: 8) {
            TranscriptOverlayControlGroup(
                title: "Position",
                options: TranscriptOverlayPosition.allCases,
                selectedOption: overlayPosition,
                label: positionLabel(_:),
                onSelect: onSelectPosition
            )

            TranscriptOverlayControlGroup(
                title: "Size",
                options: TranscriptOverlaySize.allCases,
                selectedOption: overlaySize,
                label: sizeLabel(_:),
                onSelect: onSelectSize
            )
        }
        .position(layout.controlsAnchor)
    }

    private func positionLabel(_ position: TranscriptOverlayPosition) -> String {
        switch position {
        case .top:
            "Top"
        case .center:
            "Center"
        case .bottom:
            "Bottom"
        }
    }

    private func sizeLabel(_ size: TranscriptOverlaySize) -> String {
        switch size {
        case .small:
            "S"
        case .medium:
            "M"
        case .large:
            "L"
        }
    }

    private var multilineAlignment: TextAlignment {
        switch resolvedStyle.textAlignment {
        case .leading:
            .leading
        case .center:
            .center
        case .trailing:
            .trailing
        }
    }

}

private struct TranscriptOverlayControlGroup<Option: Hashable & CaseIterable>: View {

    // MARK: - Public Properties

    let title: String
    let options: Option.AllCases
    let selectedOption: Option
    let label: (Option) -> String
    let onSelect: (Option) -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))

            ForEach(Array(options), id: \.self) { option in
                Button(label(option)) {
                    onSelect(option)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(option == selectedOption ? Theme.selection : Color.black.opacity(0.72))
                )
                .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.5))
        )
    }

}

extension Color {

    fileprivate init(rgba: RGBAColor) {
        self.init(
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            opacity: rgba.alpha
        )
    }

}
