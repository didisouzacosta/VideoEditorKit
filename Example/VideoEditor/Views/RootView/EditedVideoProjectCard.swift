//
//  EditedVideoProjectCard.swift
//  VideoEditorKit
//
//  Created by Codex on 28.03.2026.
//

import ImageIO
import SwiftUI
import VideoEditorKit

struct EditedVideoProjectCard: View {

    // MARK: - Public Properties

    let project: EditedVideoProject
    let onOpenProject: () -> Void
    let onPreviewSavedVideo: () -> Void
    let onShareSavedVideo: () -> Void
    let onDelete: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: onOpenProject) {
            thumbnailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottomLeading) {
                    if project.hasExportedVideo == false {
                        draftBadge
                            .padding(6)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if project.duration > 0 {
                        durationBadge
                            .padding(6)
                            .allowsHitTesting(false)
                    }
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

    private let cornerRadius: CGFloat = 16

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

    private var draftBadge: some View {
        Text(ExampleStrings.projectDraft)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.accent.opacity(0.9), in: Capsule())
    }

    private var menuButton: some View {
        Menu {
            Button(action: onOpenProject) {
                Label(ExampleStrings.projectEdit, systemImage: "pencil")
            }

            Button(action: onPreviewSavedVideo) {
                Label(ExampleStrings.projectPreview, systemImage: "play.rectangle")
            }
            .disabled(project.canPreviewSavedVideo == false)

            Button(action: onShareSavedVideo) {
                Label(ExampleStrings.projectShare, systemImage: "square.and.arrow.up")
            }
            .disabled(project.canShareSavedVideo == false)

            Button(role: .destructive, action: onDelete) {
                Label(ExampleStrings.projectDelete, systemImage: "trash")
            }
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
                    Image(decorative: resolvedThumbnailImage, scale: 1)
                        .resizable()
                        .scaledToFill()
                }
        } else {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.black, Theme.secondary.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: project.hasExportedVideo ? "play.rectangle.fill" : "square.and.pencil")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
        }
    }

    private var resolvedThumbnailImage: CGImage? {
        guard let thumbnailData = project.thumbnailData else { return nil }
        guard
            let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil)
        else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
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

    private static let thumbnailData: Data? = nil

}

#Preview("Edited Video Project Card") {
    EditedVideoProjectCard(
        project: EditedVideoProjectCardPreviewFixture.project,
        onOpenProject: {},
        onPreviewSavedVideo: {},
        onShareSavedVideo: {},
        onDelete: {}
    )
    .frame(width: 120, height: 120)
    .padding()
    .background(Theme.rootBackground)
}
