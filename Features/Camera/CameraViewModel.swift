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
    var sessionActiveDuration: TimeInterval = 10

    // MARK: - Callbacks
    var onPhotoSaved: ((Session) -> Void)?
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

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            errorMessage = "Unable to access camera"
            showError = true
            return
        }

        currentDevice = camera

        // Configure for natural light: continuous white balance and auto exposure
        do {
            try camera.lockForConfiguration()
            if camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                camera.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }
            // Journal pages are shot at close range — bias the AF scan near
            if camera.isAutoFocusRangeRestrictionSupported {
                camera.autoFocusRangeRestriction = .near
            }
            camera.isSubjectAreaChangeMonitoringEnabled = true
            camera.unlockForConfiguration()
        } catch {
            // Continue with defaults if configuration fails
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(subjectAreaDidChange),
            name: .AVCaptureDeviceSubjectAreaDidChange,
            object: camera
        )

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

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
            if let maxDimensions = currentDevice?.activeFormat.supportedMaxPhotoDimensions
                .max(by: { $0.width * $0.height < $1.width * $1.height }) {
                photoOutput.maxPhotoDimensions = maxDimensions
            }
        }

        session.commitConfiguration()

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
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        settings.photoQualityPrioritization = .quality

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

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let session = self.storageService.saveSession(
                image: image,
                duration: self.sessionDuration,
                activeDuration: self.sessionActiveDuration
            )
            DispatchQueue.main.async {
                self.isSaving = false
                if let session {
                    self.audioService.playHaptic(.success)
                    self.onPhotoSaved?(session)
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
        NotificationCenter.default.removeObserver(
            self,
            name: .AVCaptureDeviceSubjectAreaDidChange,
            object: currentDevice
        )
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    // MARK: - Focus

    /// Tap-to-focus at a point in capture-device coordinates (0...1)
    func focus(at devicePoint: CGPoint) {
        guard let camera = currentDevice else { return }
        do {
            try camera.lockForConfiguration()
            if camera.isFocusPointOfInterestSupported, camera.isFocusModeSupported(.autoFocus) {
                camera.focusPointOfInterest = devicePoint
                camera.focusMode = .autoFocus
            }
            if camera.isExposurePointOfInterestSupported, camera.isExposureModeSupported(.autoExpose) {
                camera.exposurePointOfInterest = devicePoint
                camera.exposureMode = .autoExpose
            }
            // Keep monitoring so continuous focus resumes when the scene changes
            camera.isSubjectAreaChangeMonitoringEnabled = true
            camera.unlockForConfiguration()
        } catch {
            // Focus is best-effort; ignore configuration failures
        }
    }

    /// Scene changed after a tap-to-focus — return to continuous auto focus/exposure
    @objc private func subjectAreaDidChange() {
        guard let camera = currentDevice else { return }
        do {
            try camera.lockForConfiguration()
            let center = CGPoint(x: 0.5, y: 0.5)
            if camera.isFocusPointOfInterestSupported {
                camera.focusPointOfInterest = center
            }
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }
            if camera.isExposurePointOfInterestSupported {
                camera.exposurePointOfInterest = center
            }
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }
            camera.unlockForConfiguration()
        } catch {
            // Best-effort
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
