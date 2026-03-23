//
//  CropSheetView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

@MainActor
struct CropSheetView: View {
    @State var rotateValue: Double = 0
    var editorVM: EditorViewModel
    @State private var currentTab: Tab = .rotate
    var body: some View {
        VStack(spacing: 28) {
            tabButtons
            Group {
                switch currentTab {
                case .format:
                    EmptyView()
                case .rotate:
                    rotateSection
                }
            }
        }
        .foregroundStyle(IOS26Theme.primaryText)
        .onAppear {
            rotateValue = editorVM.currentVideo?.rotation ?? 0
        }
        .onChange(of: editorVM.currentVideo?.rotation) { _, newValue in
            rotateValue = newValue ?? 0
        }
    }
}

extension CropSheetView {

    private var rotateSection: some View {
        HStack(spacing: 20) {
            CustomSlider(
                value: $rotateValue,
                in: 0...360,
                step: 90,
                onEditingChanged: { started in
                    if !started {
                        editorVM.currentVideo?.rotation = rotateValue
                        editorVM.setTools()
                    }
                },
                track: {
                    Capsule()
                        .fill(IOS26Theme.sliderTrack)
                        .frame(width: 200, height: 5)
                },
                thumb: {
                    Circle()
                        .fill(IOS26Theme.sliderThumb)
                }, thumbSize: CGSize(width: 20, height: 20))

            Button {
                editorVM.rotate()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(IOS26Theme.primaryText)
                    .ios26CircleControl(tint: IOS26Theme.accentSecondary)
            }
            .buttonStyle(.plain)

            Button {
                editorVM.toggleMirror()
            } label: {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(IOS26Theme.primaryText)
                    .ios26CircleControl(
                        prominent: editorVM.currentVideo?.isMirror ?? false,
                        tint: (editorVM.currentVideo?.isMirror ?? false)
                            ? IOS26Theme.accent : IOS26Theme.accentSecondary
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var tabButtons: some View {
        HStack(spacing: 12) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    currentTab = tab
                } label: {
                    Text(tab.rawValue.capitalized)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .foregroundStyle(IOS26Theme.primaryText)
                        .ios26CapsuleControl(
                            prominent: currentTab == tab,
                            tint: currentTab == tab ? IOS26Theme.accent : IOS26Theme.accentSecondary
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    enum Tab: String, CaseIterable {
        case format, rotate
    }

}

#Preview {
    CropSheetView(editorVM: EditorViewModel())
        .padding()
        .preferredColorScheme(.dark)
}
