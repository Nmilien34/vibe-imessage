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
    @Published var capturedPhoto: UIImage?
    @Published var isUploading = false
    @Published var uploadError: String?
    
    // ...
    
    func uploadVideo(userId: String, chatId: String, isLocked: Bool) async -> APIService.VideoUploadResult? {
        guard let video = recordedVideo else { return nil }

        await MainActor.run {
            self.isUploading = true
            self.uploadError = nil
        }

        do {
            let data = try Data(contentsOf: video.url)
            let result = try await APIService.shared.uploadVideo(
                videoData: data,
                userId: userId,
                chatId: chatId,
                isLocked: isLocked
            )

            await MainActor.run {
                self.isUploading = false
            }

            return result
        } catch {
            await MainActor.run {
                self.isUploading = false
                self.uploadError = error.localizedDescription
            }
            return nil
        }
    }
    
    private let sessionQueue = DispatchQueue(label: "com.vibe.cameraSession")
    private var videoOutput = AVCaptureMovieFileOutput()
    private var photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var timer: Timer?
    private var startTime: Date?
    
    private let maxDuration: TimeInterval = 15.0
    
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    override init() {
        super.init()
    }
    
    @Published var setupError: String?

    func checkPermissions() {
        if isSimulator {
            // Simulate authorized
            setupSession()
            return
        }

        // Check video permission first
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Also check/request audio permission
            checkAudioPermissionAndSetup()
        case .notDetermined:
            // Request video access
            // PAUSE SESSION IF RUNNING to avoid interruption crashes
            sessionQueue.async { [weak self] in
                if let self = self, let session = self.session, session.isRunning {
                     session.stopRunning()
                }
            }
            
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.checkAudioPermissionAndSetup()
                    } else {
                        self?.isUnauthorized = true
                        self?.setupError = "Camera access is required to record videos"
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.isUnauthorized = true
                self.setupError = "Camera access denied. Please enable in Settings."
            }
        @unknown default:
            DispatchQueue.main.async {
                self.isUnauthorized = true
            }
        }
    }

    private func checkAudioPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                // Proceed even if audio denied - video will still work
                // Ensure we call setupSession on main thread if checking access
                 DispatchQueue.main.async {
                    self?.setupSession()
                }
            }
        case .denied, .restricted:
            // Still setup session, just without audio
            setupSession()
        @unknown default:
            setupSession()
        }
    }
    
    func setupSession() {
        if isSimulator {
            // In simulator, we don't create a session, but we act as if we are ready
            return
        }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .high
            
            // Add Input (Default to Back Camera)
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("Failed to get camera device")
                DispatchQueue.main.async {
                    self.setupError = "Could not access camera. Please try again."
                    self.isUnauthorized = true
                }
                session.commitConfiguration()
                return
            }

            guard let input = try? AVCaptureDeviceInput(device: device) else {
                print("Failed to create camera input")
                DispatchQueue.main.async {
                    self.setupError = "Could not initialize camera. Please restart the app."
                    self.isUnauthorized = true
                }
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
            
            // Add Photo Output
            if session.canAddOutput(self.photoOutput) {
                session.addOutput(self.photoOutput)
            }
            
            // Audio Input - only add if we have permission
            let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            if audioStatus == .authorized {
                if let audioDevice = AVCaptureDevice.default(for: .audio),
                   let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
                   session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            } else {
                print("CameraViewModel: Skipping audio input - permission not granted (status: \(audioStatus.rawValue))")
            }
            
            session.commitConfiguration()
            session.startRunning()
            
            DispatchQueue.main.async {
                self.session = session
            }
        }
    }
    
    func reset() {
        self.recordedVideo = nil
        self.capturedPhoto = nil
        self.isRecording = false
        self.recordingTime = 0
    }

    func stopSession() {
        if isSimulator { return }
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

        if isSimulator {
            isRecording = true
            startTimer()
            return
        }

        guard let session = session, session.isRunning else {
            DispatchQueue.main.async {
                self.uploadError = "Camera not ready. Please wait and try again."
            }
            return
        }
        
        let outputUrl = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        
        videoOutput.startRecording(to: outputUrl, recordingDelegate: self)
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        if isSimulator {
            isRecording = false
            stopTimer()
            
            // Generate dummy video
            Task { @MainActor in
                let outputUrl = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
                // Write dummy data to ensure file exists
                try? "DUMMY VIDEO DATA".data(using: .utf8)?.write(to: outputUrl)
                self.recordedVideo = VideoRecording(url: outputUrl, duration: self.recordingTime)
            }
            return
        }

        videoOutput.stopRecording()
    }
    
    func takePhoto() {
        guard !isRecording else { return }
        
        if isSimulator {
            // Generate dummy photo
            let dummyImage = UIImage(systemName: "photo.fill")?.withTintColor(.pink)
            self.capturedPhoto = dummyImage
            return
        }
        
        let settings = AVCapturePhotoSettings()
        // Check for flash if needed
        if let device = videoInput?.device, device.hasFlash {
            settings.flashMode = device.torchMode == .on ? .on : .off
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func flipCamera() {
        if isSimulator { return }
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
    
    func toggleFlash(_ on: Bool) {
        if isSimulator { return }
        guard let device = videoInput?.device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Flash toggle error: \(error)")
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
    
    // Helper to generate a dummy valid video file? 
    // Swift is hard to generate video without AVAssetWriter.
    // We will assume VideoComposer handles "bad" videos gracefully in simulator.
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

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else { return }
        if let image = UIImage(data: imageData) {
            DispatchQueue.main.async {
                self.capturedPhoto = image
            }
        }
    }
}
