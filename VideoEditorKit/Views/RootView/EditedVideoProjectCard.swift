//
//  EditedVideoProjectCard.swift
//  VideoEditorKit
//
//  Created by Codex on 28.03.2026.
//

import SwiftUI
import UIKit

struct EditedVideoProjectCard: View {

    // MARK: - Public Properties

    let project: EditedVideoProject
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: onOpen) {
            thumbnailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    durationBadge
                        .padding(6)
                        .allowsHitTesting(false)
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .clipShape(cardShape)
        .overlay(alignment: .topTrailing) {
            menuButton
                .padding(6)
        }
        .overlay {
            cardShape
                .stroke(Theme.outline, lineWidth: 1)
        }
        .contentShape(cardShape)
    }

    // MARK: - Private Properties

    private let cornerRadius: CGFloat = 4

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var durationBadge: some View {
        Text(project.duration.formatterTimeString())
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.78), in: Capsule())
    }

    private var menuButton: some View {
        Menu {
            Button("Edit", action: onEdit)
            Button("Delete", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.primary)
                .frame(width: 28, height: 28)
                .background(.regularMaterial, in: Circle())
        }
        .frame(width: 40, height: 40)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let resolvedThumbnailImage {
            Rectangle()
                .overlay {
                    Image(uiImage: resolvedThumbnailImage)
                        .resizable()
                        .scaledToFill()
                }
        }
    }

    private var resolvedThumbnailImage: UIImage? {
        guard let thumbnailData = project.thumbnailData else { return nil }
        return UIImage(data: thumbnailData)
    }

}

@MainActor
private enum EditedVideoProjectCardPreviewFixture {

    // MARK: - Private Properties

    static let project = EditedVideoProject(
        createdAt: .now,
        updatedAt: .now,
        displayName: "Preview Clip",
        originalVideoFileName: "original.mp4",
        exportedVideoFileName: "exported.mp4",
        editingConfigurationData: encodedEditingConfiguration,
        thumbnailData: thumbnailData,
        duration: 24,
        width: 1080,
        height: 1080,
        fileSize: 5_242_880
    )

    private static let encodedEditingConfiguration =
        (try? JSONEncoder().encode(VideoEditingConfiguration.initial)) ?? Data()

    private static let thumbnailData: Data? = {
        let size = CGSize(width: 240, height: 240)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors =
                [
                    UIColor.systemOrange.cgColor,
                    UIColor.systemPink.cgColor,
                    UIColor.systemIndigo.cgColor,
                ] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.45, 1])

            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))

            if let gradient {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 80, weight: .bold)
            let playImage = UIImage(
                systemName: "play.rectangle.fill",
                withConfiguration: symbolConfiguration
            )?.withTintColor(.white, renderingMode: .alwaysOriginal)

            playImage?.draw(
                in: CGRect(
                    x: 76,
                    y: 76,
                    width: 88,
                    height: 88
                )
            )
        }

        return image.pngData()
    }()

}

#Preview("Edited Video Project Card") {
    EditedVideoProjectCard(
        project: EditedVideoProjectCardPreviewFixture.project,
        onOpen: {},
        onEdit: {},
        onDelete: {}
    )
    .frame(width: 120, height: 120)
    .padding()
    .background(Theme.rootBackground)
}
