//
//  SafeAreaOverlayView.swift
//  VideoEditorKit
//
//  Created by Codex on 31.03.2026.
//

import SwiftUI

struct SafeAreaOverlayView: View {

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            if let guideLayout = guideLayout(in: proxy.size) {
                let safeFrame = guideLayout.safeFrame

                ZStack {
                    unsafeRegions(guideLayout.unsafeRegions)

                    safeFrameGuide(safeFrame)

                    compositionGrid(safeFrame)

                    safeAreaLabel(safeFrame)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipShape(.rect(cornerRadius: cornerRadius))
                .allowsHitTesting(false)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Private Properties

    private let platform: SocialPlatform?
    private let insets: SafeAreaInsets?
    private let cornerRadius: CGFloat

    private var resolvedInsets: SafeAreaInsets? {
        insets ?? platform?.safeAreaInsets
    }

    // MARK: - Initializer

    init(
        platform: SocialPlatform?,
        cornerRadius: CGFloat
    ) {
        self.platform = platform
        self.insets = nil
        self.cornerRadius = cornerRadius
    }

    init(
        insets: SafeAreaInsets,
        cornerRadius: CGFloat
    ) {
        self.platform = nil
        self.insets = insets
        self.cornerRadius = cornerRadius
    }

    // MARK: - Private Methods

    private func guideLayout(
        in previewSize: CGSize
    ) -> SafeAreaGuideLayout? {
        resolvedInsets?.guideLayout(in: previewSize)
    }

    @ViewBuilder
    private func unsafeRegions(
        _ unsafeRegions: [SafeAreaGuideRegion]
    ) -> some View {
        ForEach(unsafeRegions) { region in
            Rectangle()
                .fill(regionGradient(for: region.role))
                .frame(width: region.rect.width, height: region.rect.height)
                .position(x: region.rect.midX, y: region.rect.midY)
        }
    }

    private func safeFrameGuide(
        _ safeFrame: CGRect
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: guideCornerRadius, style: .continuous)
                .fill(.white.opacity(0.03))
                .frame(width: safeFrame.width, height: safeFrame.height)
                .position(x: safeFrame.midX, y: safeFrame.midY)

            RoundedRectangle(cornerRadius: guideCornerRadius, style: .continuous)
                .strokeBorder(
                    .white.opacity(0.32),
                    lineWidth: 1
                )
                .frame(width: safeFrame.width, height: safeFrame.height)
                .position(x: safeFrame.midX, y: safeFrame.midY)

            RoundedRectangle(cornerRadius: guideCornerRadius, style: .continuous)
                .strokeBorder(
                    .white.opacity(0.82),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        dash: [10, 6]
                    )
                )
                .frame(width: safeFrame.width, height: safeFrame.height)
                .position(x: safeFrame.midX, y: safeFrame.midY)
        }
    }

    @ViewBuilder
    private func compositionGrid(
        _ safeFrame: CGRect
    ) -> some View {
        if safeFrame.width > 72, safeFrame.height > 72 {
            Path { path in
                let oneThirdWidth = safeFrame.width / 3
                let oneThirdHeight = safeFrame.height / 3

                for index in 1..<3 {
                    let x = safeFrame.minX + oneThirdWidth * CGFloat(index)
                    path.move(to: CGPoint(x: x, y: safeFrame.minY))
                    path.addLine(to: CGPoint(x: x, y: safeFrame.maxY))

                    let y = safeFrame.minY + oneThirdHeight * CGFloat(index)
                    path.move(to: CGPoint(x: safeFrame.minX, y: y))
                    path.addLine(to: CGPoint(x: safeFrame.maxX, y: y))
                }
            }
            .stroke(
                .white.opacity(0.18),
                style: StrokeStyle(
                    lineWidth: 1,
                    dash: [4, 6]
                )
            )
        }
    }

    private func regionGradient(
        for role: SafeAreaGuideRegion.Role
    ) -> LinearGradient {
        switch role {
        case .top:
            LinearGradient(
                colors: [.black.opacity(0.24), .black.opacity(0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .bottom:
            LinearGradient(
                colors: [.black.opacity(0.08), .black.opacity(0.24)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .left:
            LinearGradient(
                colors: [.black.opacity(0.22), .black.opacity(0.07)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .right:
            LinearGradient(
                colors: [.black.opacity(0.07), .black.opacity(0.22)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private func safeAreaLabel(
        _ safeFrame: CGRect
    ) -> some View {
        Text("Keep Key Content Here")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.45), in: Capsule())
            .position(
                x: safeFrame.minX + min(84, safeFrame.width / 2),
                y: safeFrame.minY + 16
            )
            .opacity(safeFrame.width > 140 && safeFrame.height > 44 ? 1 : 0)
    }

    private var guideCornerRadius: CGFloat {
        max(cornerRadius - 6, 10)
    }

}
