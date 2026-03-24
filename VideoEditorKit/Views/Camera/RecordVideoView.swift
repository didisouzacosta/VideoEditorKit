//
//  RecordVideoView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct RecordVideoView: View {
    @State private var cameraManager = CameraManager()
    @Environment(\.dismiss) private var dismiss
    let onFinishRecord: (URL) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                CameraPreviewHolder(captureSession: cameraManager.session)
                    .ignoresSafeArea()
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    if cameraManager.isRecording {
                        cameraManager.stopRecord()
                    } else {
                        cameraManager.startRecording()
                    }
                } label: {
                    Circle()
                        .fill(cameraManager.isRecording ? Theme.primary : Theme.destructive)
                        .frame(width: 55, height: 55)
                }
                .padding(.bottom, 16)
            }
            .navigationBarBackButtonHidden(true)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(Theme.primary)
                            .circleControl()
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .principal) {
                    Text(cameraManager.recordedDuration.formatterTimeString())
                        .font(.headline.monospacedDigit())
                }
            }
        }
        .onChange(of: cameraManager.finalURL) { _, newValue in
            if let url = newValue {
                onFinishRecord(url)
                dismiss()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RecordVideoView(onFinishRecord: { _ in })
}
