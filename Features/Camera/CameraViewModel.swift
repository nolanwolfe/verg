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

    // MARK: - Capture Controls
    /// True when the device can reach macro range by switching to its
    /// ultra-wide lens — i.e. when close-ups of a page will actually focus.
    @Published private(set) var supportsMacro: Bool = false
    @Published private(set) var zoomOptions: [CGFloat] = [1]
    @Published private(set) var zoomFactor: CGFloat = 1
    @Published private(set) var hasFlash: Bool = false
    @Published private(set) var isTorchOn: Bool = false

    // MARK: - Camera Properties
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    /// All session and device configuration happens here. AVCaptureSession is
    /// not thread-safe and its configuration calls block; keeping them off the
    /// main thread is what stops the camera screen hitching as it opens.
    private let sessionQueue = DispatchQueue(label: "verg.camera.session")

    // MARK: - Dependencies
    private let storageService: StorageService
    private let audioService: AudioService

    // MARK: - Session Info
    var sessionDuration: TimeInterval = 10
    var sessionActiveDuration: TimeInterval = 10
    /// Carried from the Write screen so the saved page remembers what it
    /// was written to. Nil when the user chose no prompt.
    var sessionPrompt: String?

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

    /// The back camera to shoot pages with, best first.
    ///
    /// This is the whole close-up story. The wide lens alone cannot focus
    /// nearer than roughly 10 cm, which is further than anyone holds a phone
    /// over their own handwriting — the page fills the frame but never comes
    /// sharp. iOS gets macro by *switching to the ultra-wide lens*, and it
    /// will only do that when the session is fed one of the virtual
    /// multi-camera devices below. Asking for `.builtInWideAngleCamera`
    /// directly, as this did, opts out of macro entirely.
    private func bestAvailableCamera() -> AVCaptureDevice? {
        let preferred: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,      // Pro: wide + ultra-wide + tele
            .builtInDualWideCamera,    // non-Pro modern: wide + ultra-wide
            .builtInDualCamera,        // older: wide + tele, no macro
            .builtInWideAngleCamera    // last resort, every device has one
        ]
        for type in preferred {
            if let device = AVCaptureDevice.default(type, for: .video, position: .back) {
                return device
            }
        }
        return nil
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureSessionOnQueue()
        }
    }

    /// Always runs on `sessionQueue`. AVCaptureSession configuration blocks
    /// its caller for a noticeable beat — this used to run on the main thread,
    /// stalling the UI between the timer ending and the camera appearing.
    private func configureSessionOnQueue() {
        // Already built (the screen was reopened) — just resume.
        guard session.inputs.isEmpty else {
            startRunningIfNeeded()
            return
        }

        guard let camera = bestAvailableCamera() else {
            reportSetupFailure("Unable to access camera")
            return
        }

        currentDevice = camera

        // The configuration block is deliberately its own scope, so
        // `commitConfiguration()` has definitely run before anything below
        // touches the session. A `defer` at function level would not have:
        // it fires on return, which is *after* `startRunning()`, and a
        // session started while still mid-configuration never comes up.
        let configured = applyConfiguration(for: camera)
        guard configured else { return }

        configureDevice(camera)
        publishCapabilities(for: camera)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(subjectAreaDidChange),
            name: .AVCaptureDeviceSubjectAreaDidChange,
            object: camera
        )

        startRunningIfNeeded()
    }

    /// Inputs, output, preset. Returns false (having reported the reason) if
    /// the session could not be built. Balances begin/commit on every path.
    private func applyConfiguration(for camera: AVCaptureDevice) -> Bool {
        session.beginConfiguration()
        session.sessionPreset = .photo

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: camera)
        } catch {
            session.commitConfiguration()
            reportSetupFailure("Unable to configure camera: \(error.localizedDescription)")
            return false
        }

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            reportSetupFailure("Unable to configure camera")
            return false
        }
        session.addInput(input)

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        session.commitConfiguration()

        // Photo dimensions are chosen *after* the commit, from the format that
        // is actually active. Committing the preset can change the device's
        // active format, so a size read beforehand may not be one the final
        // format accepts — and AVFoundation raises on an unsupported value
        // rather than clamping it, which takes the whole app down.
        if let maxDimensions = camera.activeFormat.supportedMaxPhotoDimensions
            .max(by: { $0.width * $0.height < $1.width * $1.height }) {
            session.beginConfiguration()
            photoOutput.maxPhotoDimensions = maxDimensions
            session.commitConfiguration()
        }

        return true
    }

    private func startRunningIfNeeded() {
        if !session.isRunning {
            session.startRunning()
        }
        DispatchQueue.main.async { [weak self] in
            self?.isCameraReady = true
        }
    }

    private func reportSetupFailure(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.showError = true
        }
    }

    /// Zoom range, macro availability, torch — published for the controls.
    private func publishCapabilities(for camera: AVCaptureDevice) {
        let hasMacro = camera.constituentDevices.contains { $0.deviceType == .builtInUltraWideCamera }
        let zooms = zoomOptions(for: camera)

        // Open on the wide lens, not the ultra-wide. On a virtual device a
        // zoom factor of 1.0 selects the *ultra-wide*, so leaving the default
        // alone would greet the user with a distorted, far-too-wide frame and
        // call it 1x. The wide lens sits at the first switch-over factor.
        var initialZoom: CGFloat = 1
        if hasMacro, let wideSwitch = zooms.dropFirst().first {
            do {
                try camera.lockForConfiguration()
                camera.videoZoomFactor = wideSwitch
                camera.unlockForConfiguration()
                initialZoom = wideSwitch
            } catch {
                // Unlocking a device we never locked is itself a crash, so
                // the unlock stays inside the successful branch.
            }
        }

        let resolvedZoom = initialZoom
        DispatchQueue.main.async { [weak self] in
            self?.supportsMacro = hasMacro
            self?.zoomOptions = zooms
            self?.zoomFactor = resolvedZoom
            self?.hasFlash = camera.hasTorch
        }
    }

    /// Focus/exposure/white-balance tuned for a sheet of paper at arm's reach.
    private func configureDevice(_ camera: AVCaptureDevice) {
        do {
            try camera.lockForConfiguration()
            defer { camera.unlockForConfiguration() }

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
            // Let the system drop to the ultra-wide when the page gets close.
            // Without this a virtual device stays on whichever lens it starts
            // on, so picking the triple camera above would buy nothing.
            if #available(iOS 16.0, *), camera.isVirtualDevice {
                camera.setPrimaryConstituentDeviceSwitchingBehavior(.auto, restrictedSwitchingBehaviorConditions: [])
            }
            camera.isSubjectAreaChangeMonitoringEnabled = true
        } catch {
            // Continue with defaults if configuration fails
        }
    }

    /// The zoom factors worth offering: ultra-wide (if present), 1x, and 2x
    /// when the hardware can reach it without visible upscaling.
    private func zoomOptions(for camera: AVCaptureDevice) -> [CGFloat] {
        var options: [CGFloat] = [1]
        if camera.constituentDevices.contains(where: { $0.deviceType == .builtInUltraWideCamera }) {
            // On a virtual device 1.0 is the ultra-wide, and the wide sits at
            // the first switch-over factor (2.0 on current hardware).
            options = [1]
            if let wideSwitch = camera.virtualDeviceSwitchOverVideoZoomFactors.first {
                options.append(CGFloat(truncating: wideSwitch))
            }
        }
        if let last = options.last, camera.maxAvailableVideoZoomFactor >= last * 2 {
            options.append(last * 2)
        }
        return options
    }

    /// Set the optical/digital zoom. On a virtual device this is also what
    /// moves between lenses, so it doubles as the macro control.
    func setZoom(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let camera = self.currentDevice else { return }
            let clamped = max(camera.minAvailableVideoZoomFactor,
                              min(factor, camera.maxAvailableVideoZoomFactor))
            do {
                try camera.lockForConfiguration()
                camera.videoZoomFactor = clamped
                camera.unlockForConfiguration()
                DispatchQueue.main.async { self.zoomFactor = clamped }
            } catch {
                // Best-effort
            }
        }
    }

    /// Candle-lit rooms are dark. The torch (not a strobe) gives even light on
    /// a page without blowing out the middle the way a flash does at 20 cm.
    func toggleTorch() {
        sessionQueue.async { [weak self] in
            guard let self, let camera = self.currentDevice, camera.hasTorch else { return }
            let turningOn = !camera.isTorchActive
            do {
                try camera.lockForConfiguration()
                camera.torchMode = turningOn ? .on : .off
                camera.unlockForConfiguration()
                DispatchQueue.main.async { self.isTorchOn = turningOn }
            } catch {
                // Best-effort
            }
        }
    }

    // MARK: - Actions
    func capturePhoto() {
        guard isCameraReady else { return }
        audioService.playImpact(.medium)

        // On the session queue, like every other call that touches the
        // output — and so `maxPhotoDimensions` is read after any in-flight
        // configuration has finished rather than racing it.
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            let settings = AVCapturePhotoSettings()
            settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
            settings.photoQualityPrioritization = .quality
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func retakePhoto() {
        capturedImage = nil
        isShowingPreview = false
    }

    func usePhoto() {
        guard let image = capturedImage else { return }

        // Saving a page is always free and unlimited — The Golden Age only gates
        // *viewing* pages older than the free archive window, not writing
        // or saving them.
        isSaving = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            // saveSession backgrounds the encode/write itself and mutates its
            // published state on the main actor, so this stays on main.
            let session = await self.storageService.saveSession(
                image: image,
                duration: self.sessionDuration,
                activeDuration: self.sessionActiveDuration,
                prompt: self.sessionPrompt
            )
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
        sessionQueue.async { [weak self] in
            guard let self else { return }
            // Leaving the torch burning would keep it lit behind the app.
            if let camera = self.currentDevice, camera.hasTorch, camera.isTorchActive {
                // unlockForConfiguration() without a matching successful lock
                // is itself a crash, so it stays inside the `do`.
                do {
                    try camera.lockForConfiguration()
                    camera.torchMode = .off
                    camera.unlockForConfiguration()
                } catch {
                    // Best-effort
                }
            }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isTorchOn = false }
        }
    }

    // MARK: - Focus

    /// Tap-to-focus at a point in capture-device coordinates (0...1)
    func focus(at devicePoint: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let camera = self?.currentDevice else { return }
            do {
                try camera.lockForConfiguration()
                defer { camera.unlockForConfiguration() }
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
            } catch {
                // Focus is best-effort; ignore configuration failures
            }
        }
    }

    /// Scene changed after a tap-to-focus — return to continuous auto focus/exposure
    @objc private func subjectAreaDidChange() {
        sessionQueue.async { [weak self] in
            guard let camera = self?.currentDevice else { return }
            do {
                try camera.lockForConfiguration()
                defer { camera.unlockForConfiguration() }
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
            } catch {
                // Best-effort
            }
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

        // Still on the capture queue — do the (usually free) format pass here
        // rather than on main. A `.photo`-preset capture is already 3:4, so
        // this normally returns the same image straight back.
        let page = PageCapture.normalized(image)

        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = page
            self?.isShowingPreview = true
        }
    }
}
