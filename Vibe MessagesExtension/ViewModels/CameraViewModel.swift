//
//  CameraViewModel.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI
import AVFoundation
import Combine

// Uses VideoRecording from Models/VideoRecording.swift

class CameraViewModel: NSObject, ObservableObject {
    @Published var session: AVCaptureSession?
    @Published var isUnauthorized = false
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var recordedVideo: VideoRecording?
    
    private let sessionQueue = DispatchQueue(label: "com.vibe.cameraSession")
    private var videoOutput = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var timer: Timer?
    private var startTime: Date?
    
    private let maxDuration: TimeInterval = 15.0
    
    override init() {
        super.init()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.setupSession()
                } else {
                    DispatchQueue.main.async {
                        self?.isUnauthorized = true
                    }
                }
            }
        case .denied, .restricted:
            isUnauthorized = true
        @unknown default:
            isUnauthorized = true
        }
    }
    
    func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .high
            
            // Add Input (Default to Back Camera)
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                print("Failed to get camera device")
                session.commitConfiguration()
                return
            }
            
            if session.canAddInput(input) {
                session.addInput(input)
                self.videoInput = input
            }
            
            // Add Output
            if session.canAddOutput(self.videoOutput) {
                session.addOutput(self.videoOutput)
            }
            
            // Audio Input
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
               session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
            
            session.commitConfiguration()
            session.startRunning()
            
            DispatchQueue.main.async {
                self.session = session
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.session?.stopRunning()
            DispatchQueue.main.async {
                self?.session = nil
            }
        }
    }
    
    // MARK: - Recording Logic
    
    func startRecording() {
        guard !isRecording else { return }
        guard let session = session, session.isRunning else { return }
        
        let outputPath = NSTemporaryDirectory() + UUID().uuidString + ".mov"
        let outputUrl = URL(fileURLWithPath: outputPath)
        
        videoOutput.startRecording(to: outputUrl, recordingDelegate: self)
    }
    
    func stopRecording() {
        guard isRecording else { return }
        videoOutput.stopRecording()
    }
    
    func flipCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.session else { return }
            
            session.beginConfiguration()
            
            // Remove existing input
            if let currentInput = self.videoInput {
                session.removeInput(currentInput)
            }
            
            // Find new camera
            let currentPosition = self.videoInput?.device.position ?? .back
            let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
            
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newTaskInput = try? AVCaptureDeviceInput(device: newDevice) else {
                // Restore old input if fail
                if let oldInput = self.videoInput {
                    session.addInput(oldInput)
                }
                session.commitConfiguration()
                return
            }
            
            if session.canAddInput(newTaskInput) {
                session.addInput(newTaskInput)
                self.videoInput = newTaskInput
            }
            
            session.commitConfiguration()
        }
    }
    
    private func startTimer() {
        startTime = Date()
        recordingTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }
            let duration = Date().timeIntervalSince(start)
            self.recordingTime = duration
            
            if duration >= self.maxDuration {
                self.stopRecording()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        startTime = nil
        recordingTime = 0
    }
}

extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async {
            self.isRecording = true
            self.startTimer()
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.stopTimer()
            
            if let error = error {
                print("Recording error: \(error.localizedDescription)")
                // Handle specific success cases even with errors (like max duration reached)
                let success = (error as NSError).code == AVError.maximumDurationReached.rawValue || (error as NSError).code == AVError.diskFull.rawValue || (error as NSError).code == AVError.sessionWasInterrupted.rawValue
                   
                if !success { return }
            }
            
            self.recordedVideo = VideoRecording(url: outputFileURL, duration: self.recordingTime)
        }
    }
}
