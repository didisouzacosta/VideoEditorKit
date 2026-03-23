//
//  CameraPreviewView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI
import AVFoundation

final class CameraManager: NSObject, ObservableObject, @unchecked Sendable {
    
    enum Status{
        case unconfigurate
        case configurate
        case unauthorized
        case faild
    }
    
    @Published var error: CameraError?
    @Published var session = AVCaptureSession()
    @Published var finalURL: URL?
    @Published var recordedDuration: Double = .zero
    @Published var cameraPosition: AVCaptureDevice.Position = .front
    
    let maxDuration: Double = 100 // sec
    private var timer: Timer?
    private let sessionQueue = DispatchQueue(label: "com.VideoEditorKit.camera.session", qos: .userInitiated)
    private let videoOutput = AVCaptureMovieFileOutput()
    private var status: Status = .unconfigurate
    
    var isRecording: Bool{
        videoOutput.isRecording
    }
    
    override init(){
        super.init()
        config()
    }
    
    private func config(){
        checkPermissions()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configCaptureSession()
            guard self.status == .configurate else { return }
            self.session.startRunning()
        }
    }
    
    func controllSession(start: Bool){
        guard status == .configurate else {
            config()
            return
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if start{
                if !self.session.isRunning{
                    self.session.startRunning()
                }
            }else{
                self.session.stopRunning()
            }
        }
    }
    
    private func setError(_ error: CameraError?){
        Task { @MainActor [weak self] in
            self?.error = error
        }
    }

    private func setFinalURL(_ url: URL) {
        Task { @MainActor [weak self] in
            self?.finalURL = url
        }
    }
    
    ///Check user permissions
    private func checkPermissions(){
        switch AVCaptureDevice.authorizationStatus(for: .video){
            
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { aurhorized in
                if !aurhorized{
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
    
    ///Configuring a session and adding video, audio input and adding video output
    private func configCaptureSession(){
        guard status == .unconfigurate else {
            return
        }
        session.beginConfiguration()
        
        session.sessionPreset = .hd1280x720
        
        let device = getCameraDevice(for: .back)
        let audioDevice = AVCaptureDevice.default(for: .audio)
        
        guard let camera = device, let audio = audioDevice else {
            setError(.cameraUnavalible)
            status = .faild
            return
        }
        
        do{
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            let audioInput = try AVCaptureDeviceInput(device: audio)
            
            if session.canAddInput(cameraInput) && session.canAddInput(audioInput){
                session.addInput(audioInput)
                session.addInput(cameraInput)
            }else{
                setError(.cannotAddInput)
                status = .faild
                return
            }
        }catch{
            setError(.createCaptureInput(error))
            status = .faild
            return
        }
        
        if session.canAddOutput(videoOutput){
            session.addOutput(videoOutput)
        }else{
            setError(.cannotAddInput)
            status = .faild
            return
        }
        
        session.commitConfiguration()
        status = .configurate
    }
    
    
   private func getCameraDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera, .builtInTelephotoCamera, .builtInDualCamera, .builtInTrueDepthCamera, .builtInDualWideCamera], mediaType: AVMediaType.video, position: .unspecified)
        for device in discoverySession.devices {
            if device.position == position {
                return device
            }
        }
        return nil
    }
    
    func stopRecord(){
        timer?.invalidate()
        videoOutput.stopRecording()
    }
    
    func startRecording(){
        ///Temporary URL for recording Video
        recordedDuration = .zero
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(UUID().uuidString).mov")
        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
        startTimer()
    }
    
//    func set(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate,
//             queue: DispatchQueue){
//        sessionQueue.async {
//            self.videoOutput.setSampleBufferDelegate(delegate, queue: queue)
//        }
//    }
    
    
}



extension CameraManager{
    
    private func onTimerFires(){
        
        if recordedDuration <= maxDuration && videoOutput.isRecording{
            recordedDuration += 1
        }
        if recordedDuration >= maxDuration && videoOutput.isRecording{
            stopRecord()
        }
    }
    
    private func startTimer(){
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] (timer) in
                self?.onTimerFires()
            }
        }
    }
}



extension CameraManager: AVCaptureFileOutputRecordingDelegate{
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error{
            setError(.outputError(error))
        }else{
            setFinalURL(outputFileURL)
        }
    }
    
    
}



enum CameraError: Error{
    case deniedAuthorization
    case restrictedAuthorization
    case unknowAuthorization
    case cameraUnavalible
    case cannotAddInput
    case createCaptureInput(Error)
    case outputError(Error)
}
