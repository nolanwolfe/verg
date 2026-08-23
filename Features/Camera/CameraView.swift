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
                .padding(.top, Theme.Spacing.sm)

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
        .padding(.bottom, Theme.Spacing.md)
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
        VStack(spacing: Theme.Spacing.xl) {
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
                .aspectRatio(3/4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium, style: .continuous))
                .padding(.horizontal, Theme.Spacing.md)

                if !viewModel.isCameraReady {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primaryText))
                }
            }

            Spacer()

            captureButton

            // Library picker
            Button {
                viewModel.showPhotoPicker = true
            } label: {
                Text("Choose from Library")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
            }

            Spacer()
                .frame(height: Theme.Spacing.xxl)
        }
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
                DispatchQueue.main.async {
                    self?.parent.selectedImage = image as? UIImage
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
