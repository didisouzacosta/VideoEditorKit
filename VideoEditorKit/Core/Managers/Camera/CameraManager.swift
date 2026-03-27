//
//  CameraPreviewView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVFoundation
import Observation
import SwiftUI

protocol CameraRecordingOutput: AnyObject {

    // MARK: - Public Properties

    var isRecording: Bool { get }

    // MARK: - Public Methods

    func startRecording(to outputFileURL: URL, recordingDelegate: AVCaptureFileOutputRecordingDelegate)
    func stopRecording()
    func setMaximumRecordedDuration(seconds: Double)
    func addToSession(_ session: AVCaptureSession) -> Bool

}

extension AVCaptureMovieFileOutput: CameraRecordingOutput {

    func setMaximumRecordedDuration(seconds: Double) {
        maxRecordedDuration = CMTime(seconds: seconds, preferredTimescale: 1)
    }

    func addToSession(_ session: AVCaptureSession) -> Bool {
        guard session.canAddOutput(self) else { return false }
        session.addOutput(self)
        return true
    }

}

@Observable
final class CameraManager: NSObject, @unchecked Sendable {

    // MARK: - Public Properties

    let maxDuration: Double

    var error: CameraError?
    var session: AVCaptureSession
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
    private let videoOutput: any CameraRecordingOutput

    @ObservationIgnored
    private var status: Status = .unconfigurate

    @ObservationIgnored
    private let sleep: @Sendable (Duration) async throws -> Void

    @ObservationIgnored
    private let temporaryURLProvider: () -> URL

    // MARK: - Initializer

    init(
        maxDuration: Double = 100,
        session: AVCaptureSession = AVCaptureSession(),
        videoOutput: any CameraRecordingOutput = AVCaptureMovieFileOutput(),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { duration in
            try await ContinuousClock().sleep(for: duration)
        },
        temporaryURLProvider: @escaping () -> URL = {
            URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
        },
        autoConfigure: Bool = true
    ) {
        self.maxDuration = maxDuration
        self.session = session
        self.videoOutput = videoOutput
        self.sleep = sleep
        self.temporaryURLProvider = temporaryURLProvider
        super.init()

        if autoConfigure {
            config()
        }
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

        let tempURL = temporaryURLProvider()

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
        if Thread.isMainThread {
            self.error = error
        } else {
            Task { @MainActor [weak self] in
                self?.error = error
            }
        }
    }

    private func setFinalURL(_ url: URL) {
        if Thread.isMainThread {
            finalURL = url
        } else {
            Task { @MainActor [weak self] in
                self?.finalURL = url
            }
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

        if videoOutput.addToSession(session) {
            videoOutput.setMaximumRecordedDuration(seconds: maxDuration)
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
            while !Task.isCancelled {
                guard let self else { return }

                do {
                    try await self.sleep(.seconds(1))
                } catch {
                    return
                }

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
