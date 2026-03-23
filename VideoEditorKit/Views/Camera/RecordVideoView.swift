//
//  RecordVideoView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct RecordVideoView: View {
    @StateObject var cameraManager = CameraManager()
    @Environment(\.dismiss) private var dismiss
    let onFinishRecord: (URL) -> Void
    var body: some View {
        ZStack{
            CameraPreviewHolder(captureSession: cameraManager.session)
            VStack(spacing: 0) {
                Text(cameraManager.recordedDuration.formatterTimeString())
                    .foregroundColor(.white)
                Spacer()
                Button {
                    if cameraManager.isRecording{
                        cameraManager.stopRecord()
                    }else{
                        cameraManager.startRecording()
                    }
                    
                } label: {
                    Circle()
                        .fill(cameraManager.isRecording ? .white : .red)
                        .frame(width: 55, height: 55)
                }
            }
            .padding()
        }
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .padding()
            }
        }
        .onChange(of: cameraManager.finalURL) { newValue in
            if let url = newValue{
                onFinishRecord(url)
                dismiss()
            }
        }
    }
}

struct RecordVideoView_Previews: PreviewProvider {
    static var previews: some View {
        RecordVideoView( onFinishRecord: {_ in })
    }
}
