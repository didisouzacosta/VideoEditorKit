//
//  CropToolView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

@MainActor
struct CropToolView: View {

    // MARK: - Private Properties

    private let editorVM: EditorViewModel

    // MARK: - Body

    var body: some View {
        VStack(spacing: 28) {
            tabButtons
            Group {
                switch editorVM.cropTab {
                case .format:
                    EmptyView()
                case .rotate:
                    rotateSection
                }
            }
        }
    }

    // MARK: - Initializer

    init(_ editorVM: EditorViewModel) {
        self.editorVM = editorVM
    }

}

extension CropToolView {

    // MARK: - Private Properties

    private var rotateSection: some View {
        @Bindable var bindableEditorVM = editorVM

        return HStack(spacing: 20) {
            CustomSlider(
                $bindableEditorVM.cropRotation,
                in: 0...360,
                step: 90,
                onEditingChanged: { _ in },
                onChanged: {},
                track: {
                    Capsule()
                        .fill(Theme.sliderTrack)
                        .frame(width: 200, height: 5)
                },
                thumb: {
                    Circle()
                        .fill(Theme.sliderThumb)
                }, thumbSize: CGSize(width: 20, height: 20))

            Button {
                editorVM.rotate()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .circleControl(tint: Theme.secondary)
            }

            Button {
                editorVM.toggleMirror()
            } label: {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .circleControl(
                        prominent: editorVM.isMirrorEnabled,
                        tint: editorVM.isMirrorEnabled ? Theme.accent : Theme.secondary
                    )
            }
        }
    }

    private var tabButtons: some View {
        HStack(spacing: 12) {
            ForEach(EditorViewModel.CropToolTab.allCases, id: \.self) { tab in
                Button {
                    editorVM.cropTab = tab
                } label: {
                    Text(tab.rawValue.capitalized)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .capsuleControl(
                            prominent: editorVM.isCropTabSelected(tab),
                            tint: editorVM.isCropTabSelected(tab) ? Theme.accent : Theme.secondary
                        )
                }
            }
        }
    }

}

#Preview {
    CropToolView(EditorViewModel())
        .padding()
        .preferredColorScheme(.dark)
}
