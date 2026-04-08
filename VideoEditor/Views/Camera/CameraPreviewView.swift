//
//  CameraPreviewView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVKit
import SwiftUI

final class CameraPreviewView: UIView {

    private let captureSession: AVCaptureSession

    init(_ captureSession: AVCaptureSession) {
        self.captureSession = captureSession
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    private var videoPreviewLayer: AVCaptureVideoPreviewLayer? {
        layer as? AVCaptureVideoPreviewLayer
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        guard let videoPreviewLayer else {
            assertionFailure("Expected AVCaptureVideoPreviewLayer backing layer.")
            return
        }

        if superview != nil {
            videoPreviewLayer.session = captureSession
            videoPreviewLayer.videoGravity = .resizeAspectFill
        } else {
            videoPreviewLayer.session = nil
            videoPreviewLayer.removeFromSuperlayer()
        }
    }

}

struct CameraPreviewHolder: UIViewRepresentable {

    // MARK: - Public Properties

    typealias UIViewType = CameraPreviewView

    // MARK: - Private Properties

    private var captureSession: AVCaptureSession

    // MARK: - Initializer

    init(_ captureSession: AVCaptureSession) {
        self.captureSession = captureSession
    }

    // MARK: - Public Methods

    func makeUIView(context: Context) -> CameraPreviewView {
        CameraPreviewView(captureSession)
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {}

}
