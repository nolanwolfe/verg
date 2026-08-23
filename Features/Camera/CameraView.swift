import SwiftUI
import AVFoundation
import UIKit
import PhotosUI

/// Camera screen for capturing journal page photo
struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var focusPoint: CGPoint?
    @State private var focusRingScale: CGFloat = 1.4
    @State private var focusRingOpacity: Double = 0

    var duration: TimeInterval = 10
    var activeDuration: TimeInterval = 10
    var prompt: String?
    var onPhotoSaved: ((Session) -> Void)?
    var onCancel: (() -> Void)?

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                if viewModel.isShowingPreview, let image = viewModel.capturedImage {
                    previewView(image: image)
                } else {
                    #if targetEnvironment(simulator)
                    simulatorView
                    #else
                    cameraView
                    #endif
                }
            }

            if viewModel.isSaving {
                savingOverlay
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .sheet(isPresented: $viewModel.showPhotoPicker) {
            PhotoPicker(selectedImage: $viewModel.capturedImage)
                .onDisappear {
                    if viewModel.capturedImage != nil {
                        viewModel.isShowingPreview = true
                    }
                }
        }
        .onAppear {
            viewModel.sessionDuration = duration
            viewModel.sessionActiveDuration = activeDuration
            viewModel.sessionPrompt = prompt
            viewModel.onPhotoSaved = { session in
                onPhotoSaved?(session)
            }
            viewModel.onCancel = {
                onCancel?()
            }
            #if !targetEnvironment(simulator)
            viewModel.setupCamera()
            #endif
        }
        .onDisappear {
            #if !targetEnvironment(simulator)
            viewModel.stopCamera()
            #endif
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            HStack {
                Button {
                    viewModel.cancel()
                } label: {
                    Text("Cancel")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }

                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)

            Text("Capture Your Page")
                .font(Theme.Typography.title)
                .foregroundColor(Theme.Colors.primaryText)
                .padding(.top, Theme.Spacing.xxxs)

            #if targetEnvironment(simulator)
            Text("Select a photo from your library")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
            #else
            Text("Take a photo of your journal entry")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
            #endif
        }
        // Chrome is kept tight here: every point this header gives up goes
        // straight into the viewfinder below it.
        .padding(.bottom, Theme.Spacing.xs)
    }

    // MARK: - Simulator View
    #if targetEnvironment(simulator)
    private var simulatorView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium, style: .continuous)
                    .fill(Theme.Colors.cardBackground)
                    .aspectRatio(3/4, contentMode: .fit)
                    .padding(.horizontal, Theme.Spacing.md)

                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.Colors.secondaryText)

                    Text("Simulator Mode")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.secondaryText)

                    Text("Camera not available")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText.opacity(0.7))
                }
            }

            Spacer()

            Button {
                viewModel.showPhotoPicker = true
            } label: {
                HStack {
                    Image(systemName: "photo.stack")
                    Text("Select from Library")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()
                .frame(height: Theme.Spacing.xxl)
        }
    }
    #endif

    // MARK: - Camera View
    private var cameraView: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                CameraPreviewView(session: viewModel.session, onTap: { devicePoint, layerPoint in
                    viewModel.focus(at: devicePoint)
                    showFocusRing(at: layerPoint)
                })
                .overlay {
                    if let focusPoint {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.Colors.flameOuter, lineWidth: 1.5)
                            .frame(width: 70, height: 70)
                            .scaleEffect(focusRingScale)
                            .opacity(focusRingOpacity)
                            .position(focusPoint)
                            .allowsHitTesting(false)
                    }
                }
                .aspectRatio(PageCapture.aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium, style: .continuous))
                .padding(.horizontal, Theme.Spacing.xxs)

                if !viewModel.isCameraReady {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primaryText))
                }
            }

            zoomSelector

            Spacer()

            HStack {
                Spacer()
                captureButton
                    .overlay(alignment: .trailing) {
                        if viewModel.hasFlash {
                            torchButton
                                .offset(x: 76)
                        }
                    }
                Spacer()
            }

            // Library picker
            Button {
                viewModel.showPhotoPicker = true
            } label: {
                Text("Choose from Library")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
            }

            Spacer()
                .frame(height: Theme.Spacing.md)
        }
    }

    // MARK: - Zoom Selector
    /// Only shown when there is a real choice to make. On a device whose back
    /// camera is a single wide lens there is nothing to switch to, and an
    /// inert "1x" pill would just be furniture.
    @ViewBuilder
    private var zoomSelector: some View {
        if viewModel.zoomOptions.count > 1 {
            HStack(spacing: Theme.Spacing.xxs) {
                ForEach(viewModel.zoomOptions, id: \.self) { factor in
                    let isSelected = abs(viewModel.zoomFactor - factor) < 0.05
                    Button {
                        AudioService.shared.playUITick()
                        viewModel.setZoom(factor)
                    } label: {
                        Text(zoomLabel(factor))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? Theme.Colors.background : Theme.Colors.primaryText)
                            .frame(width: 44, height: 32)
                            .background(
                                Capsule().fill(
                                    isSelected
                                        ? Theme.Colors.primaryText
                                        : Theme.Colors.cardBackground
                                )
                            )
                    }
                }
            }
        }
    }

    /// Labelled relative to the wide lens, so it reads "1x" / "2x" whether or
    /// not the device's zoom scale actually starts there.
    private func zoomLabel(_ factor: CGFloat) -> String {
        guard let base = viewModel.zoomOptions.first, base > 0 else { return "1x" }
        return String(format: "%gx", factor / base)
    }

    // MARK: - Torch
    private var torchButton: some View {
        Button {
            AudioService.shared.playUITick()
            viewModel.toggleTorch()
        } label: {
            Image(systemName: viewModel.isTorchOn ? "bolt.fill" : "bolt.slash")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(viewModel.isTorchOn ? Theme.Colors.flameOuter : Theme.Colors.secondaryText)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(viewModel.isTorchOn ? "Turn light off" : "Turn light on")
    }

    private func showFocusRing(at point: CGPoint) {
        focusPoint = point
        focusRingScale = 1.4
        focusRingOpacity = 1
        withAnimation(.easeOut(duration: 0.25)) {
            focusRingScale = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                focusRingOpacity = 0
            }
        }
    }

    // MARK: - Capture Button
    private var captureButton: some View {
        Button {
            viewModel.capturePhoto()
        } label: {
            ZStack {
                Circle()
                    .stroke(Theme.Colors.primaryText, lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(Theme.Colors.primaryText)
                    .frame(width: 66, height: 66)
            }
        }
        .disabled(!viewModel.isCameraReady)
        .opacity(viewModel.isCameraReady ? 1 : 0.5)
    }

    // MARK: - Preview View
    private func previewView(image: UIImage) -> some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium, style: .continuous))
                .padding(.horizontal, Theme.Spacing.md)

            Spacer()

            HStack(spacing: Theme.Spacing.md) {
                Button {
                    viewModel.retakePhoto()
                } label: {
                    #if targetEnvironment(simulator)
                    Text("Choose Another")
                    #else
                    Text("Retake")
                    #endif
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    viewModel.usePhoto()
                } label: {
                    Text("Use Photo")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, Theme.Spacing.md)

            Spacer()
                .frame(height: Theme.Spacing.xxl)
        }
    }

    // MARK: - Saving Overlay
    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.md) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primaryText))
                    .scaleEffect(1.5)

                Text("Saving...")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
            }
        }
    }
}

// MARK: - Photo Picker
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                guard let picked = image as? UIImage else { return }
                // Library photos arrive in whatever shape they were shot or
                // screenshotted in. Cropping to the page format here — off
                // the main thread, before anything sees it — is what keeps a
                // picked page the same shape as a captured one. The preview
                // screen then shows the actual cropped result, so "Use Photo"
                // never saves something different from what was on screen.
                let page = PageCapture.normalized(picked)
                DispatchQueue.main.async {
                    self?.parent.selectedImage = page
                }
            }
        }
    }
}

// MARK: - Camera Preview View (UIViewRepresentable)
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    /// Called on tap with (devicePoint 0...1 for focus, layerPoint for UI indicator)
    var onTap: ((CGPoint, CGPoint) -> Void)?

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        view.onTap = onTap
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.onTap = onTap
    }
}

/// Custom UIView that properly manages the AVCaptureVideoPreviewLayer
class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            setupPreviewLayer()
        }
    }

    var onTap: ((CGPoint, CGPoint) -> Void)?

    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let previewLayer else { return }
        let layerPoint = gesture.location(in: self)
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
        onTap?(devicePoint, layerPoint)
    }

    private func setupPreviewLayer() {
        previewLayer?.removeFromSuperlayer()

        guard let session = session else { return }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.addSublayer(layer)
        previewLayer = layer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

// MARK: - Preview
#Preview {
    CameraView()
}
