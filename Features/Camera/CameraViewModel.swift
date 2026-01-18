import Foundation
import AVFoundation
import UIKit
import Combine

/// ViewModel for the Camera screen
final class CameraViewModel: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published var capturedImage: UIImage?
    @Published var isShowingPreview: Bool = false
    @Published var isCameraReady: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var isSaving: Bool = false
    @Published var showPhotoPicker: Bool = false

    // MARK: - Camera Properties
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?

    // MARK: - Dependencies
    private let storageService: StorageService
    private let audioService: AudioService

    // MARK: - Session Info
    var sessionDuration: TimeInterval = 10

    // MARK: - Callbacks
    var onPhotoSaved: (() -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - Initialization
    init(
        storageService: StorageService = .shared,
        audioService: AudioService = .shared
    ) {
        self.storageService = storageService
        self.audioService = audioService
        super.init()
    }

    // MARK: - Camera Setup
    func setupCamera() {
        // Check authorization
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.configureSession()
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Camera access is required to capture your journal page."
                        self?.showError = true
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = "Camera access is required. Please enable it in Settings."
            showError = true
        @unknown default:
            break
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Add input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            errorMessage = "Unable to access camera"
            showError = true
            return
        }

        currentDevice = camera

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            errorMessage = "Unable to configure camera: \(error.localizedDescription)"
            showError = true
            return
        }

        // Add output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            // Configure for maximum resolution
            if let maxDimensions = currentDevice?.activeFormat.supportedMaxPhotoDimensions.max(by: { $0.width * $0.height < $1.width * $1.height }) {
                photoOutput.maxPhotoDimensions = maxDimensions
            }
        }

        session.commitConfiguration()

        // Start session on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isCameraReady = true
            }
        }
    }

    // MARK: - Actions
    func capturePhoto() {
        guard isCameraReady else { return }

        let settings = AVCapturePhotoSettings()
        // Use max photo dimensions for high resolution capture
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions

        // Play shutter haptic
        audioService.playImpact(.medium)

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func retakePhoto() {
        capturedImage = nil
        isShowingPreview = false
    }

    func usePhoto() {
        guard let image = capturedImage else { return }

        isSaving = true

        // Save to storage
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let session = self.storageService.saveSession(
                image: image,
                duration: self.sessionDuration
            )

            DispatchQueue.main.async {
                self.isSaving = false

                if session != nil {
                    self.audioService.playHaptic(.success)
                    self.onPhotoSaved?()
                } else {
                    self.errorMessage = "Failed to save photo. Please try again."
                    self.showError = true
                }
            }
        }
    }

    func cancel() {
        stopCamera()
        onCancel?()
    }

    func stopCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Failed to capture photo: \(error.localizedDescription)"
                self?.showError = true
            }
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Failed to process photo"
                self?.showError = true
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = image
            self?.isShowingPreview = true
        }
    }
}
