//
//  CameraPreviewView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVFoundation
import Observation
import SwiftUI

@Observable
final class CameraManager: NSObject, @unchecked Sendable {

    // MARK: - Public Properties

    let maxDuration: Double = 100

    var error: CameraError?
    var session = AVCaptureSession()
    var finalURL: URL?
    var recordedDuration: Double = .zero
    var cameraPosition: AVCaptureDevice.Position = .back

    var isRecording: Bool {
        videoOutput.isRecording
    }

    // MARK: - Private Properties

    @ObservationIgnored
    private var recordingDurationTask: Task<Void, Never>?
    
    @ObservationIgnored
    private let sessionQueue = DispatchQueue(label: "com.VideoEditorKit.camera.session", qos: .userInitiated)
    
    @ObservationIgnored
    private let videoOutput = AVCaptureMovieFileOutput()
    
    @ObservationIgnored
    private var status: Status = .unconfigurate

    // MARK: - Initializer

    override init() {
        super.init()
        config()
    }

    // MARK: - Public Methods

    func controllSession(start: Bool) {
        guard status == .configurate else {
            config()
            return
        }
        
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if start {
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            } else {
                self.session.stopRunning()
            }
        }
    }

    func stopRecord() {
        stopRecordingDurationUpdates()
        videoOutput.stopRecording()
    }

    func toggleRecording() {
        if isRecording {
            stopRecord()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        recordedDuration = .zero

        let tempURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")

        videoOutput.startRecording(to: tempURL, recordingDelegate: self)

        startRecordingDurationUpdates()
    }

    // MARK: - Private Methods

    private func config() {
        checkPermissions()

        sessionQueue.async { [weak self] in
            guard let self else { return }

            self.configCaptureSession()

            guard self.status == .configurate else { return }

            self.session.startRunning()
        }
    }

    private func setError(_ error: CameraError?) {
        Task { @MainActor [weak self] in
            self?.error = error
        }
    }

    private func setFinalURL(_ url: URL) {
        Task { @MainActor [weak self] in
            self?.finalURL = url
        }
    }

    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {

        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { aurhorized in
                if !aurhorized {
                    self.status = .unauthorized
                    self.setError(.deniedAuthorization)
                }
                self.sessionQueue.resume()
            }
        case .restricted:
            status = .unauthorized
            setError(.restrictedAuthorization)
        case .denied:
            status = .unauthorized
            setError(.deniedAuthorization)

        case .authorized: break
        @unknown default:
            status = .unauthorized
            setError(.unknowAuthorization)
        }
    }

    private func configCaptureSession() {
        guard status == .unconfigurate else { return }

        session.beginConfiguration()
        
        defer { session.commitConfiguration() }
        
        session.sessionPreset = .hd1280x720

        let device = getCameraDevice(for: cameraPosition)
        let audioDevice = AVCaptureDevice.default(for: .audio)

        guard let camera = device, let audio = audioDevice else {
            setError(.cameraUnavalible)
            status = .faild
            return
        }

        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            let audioInput = try AVCaptureDeviceInput(device: audio)

            if session.canAddInput(cameraInput) && session.canAddInput(audioInput) {
                session.addInput(audioInput)
                session.addInput(cameraInput)
            } else {
                setError(.cannotAddInput)
                status = .faild
                return
            }
        } catch {
            setError(.createCaptureInput(error))
            status = .faild
            return
        }

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.maxRecordedDuration = CMTime(seconds: maxDuration, preferredTimescale: 1)
        } else {
            setError(.cannotAddInput)
            status = .faild
            return
        }

        status = .configurate
    }

    private func getCameraDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTripleCamera, .builtInTelephotoCamera, .builtInDualCamera, .builtInTrueDepthCamera,
                .builtInDualWideCamera,
            ], mediaType: AVMediaType.video, position: .unspecified)

        for device in discoverySession.devices {
            if device.position == position {
                return device
            }
        }

        return nil
    }

}

extension CameraManager {

    enum Status {
        case unconfigurate
        case configurate
        case unauthorized
        case faild
    }

    // MARK: - Public Methods

    func consumeFinalURL() -> URL? {
        let url = finalURL
        finalURL = nil
        return url
    }

    // MARK: - Private Methods

    private func startRecordingDurationUpdates() {
        recordingDurationTask = Task { [weak self] in
            let clock = ContinuousClock()

            while !Task.isCancelled {
                do {
                    try await clock.sleep(for: .seconds(1))
                } catch {
                    return
                }

                guard let self else { return }
                guard videoOutput.isRecording else { return }

                recordedDuration = min(recordedDuration + 1, maxDuration)

                if recordedDuration >= maxDuration {
                    stopRecord()
                    return
                }
            }
        }
    }

    private func stopRecordingDurationUpdates() {
        recordingDurationTask?.cancel()
        recordingDurationTask = nil
    }

}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {

    // MARK: - Public Methods

    func fileOutput(
        _ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection], error: Error?
    ) {
        stopRecordingDurationUpdates()

        if let error {
            setError(.outputError(error))
        } else {
            setFinalURL(outputFileURL)
        }
    }

}
