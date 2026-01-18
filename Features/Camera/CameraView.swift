import SwiftUI
import AVFoundation
import UIKit
import PhotosUI

/// Camera screen for capturing journal page photo
struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.dismiss) private var dismiss

    var duration: TimeInterval = 10
    var onPhotoSaved: (() -> Void)?
    var onCancel: (() -> Void)?

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                if viewModel.isShowingPreview, let image = viewModel.capturedImage {
                    // Preview mode
                    previewView(image: image)
                } else {
                    // Camera/Picker mode
                    #if targetEnvironment(simulator)
                    simulatorView
                    #else
                    cameraView
                    #endif
                }
            }

            // Loading overlay
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
            viewModel.onPhotoSaved = {
                onPhotoSaved?()
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

    // MARK: - Simulator View (Photo Picker)
    #if targetEnvironment(simulator)
    private var simulatorView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // Placeholder area
            ZStack {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
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

            // Select from Library button
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
            // Camera preview
            ZStack {
                CameraPreviewView(session: viewModel.session)
                    .aspectRatio(3/4, contentMode: .fit)
                    .cornerRadius(Theme.CornerRadius.medium)
                    .padding(.horizontal, Theme.Spacing.md)

                if !viewModel.isCameraReady {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primaryText))
                }
            }

            Spacer()

            // Capture button
            captureButton

            Spacer()
                .frame(height: Theme.Spacing.xxl)
        }
    }

    // MARK: - Capture Button
    private var captureButton: some View {
        Button {
            viewModel.capturePhoto()
        } label: {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Theme.Colors.primaryText, lineWidth: 4)
                    .frame(width: 80, height: 80)

                // Inner circle
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
            // Image preview
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(Theme.CornerRadius.medium)
                .padding(.horizontal, Theme.Spacing.md)

            Spacer()

            // Action buttons
            HStack(spacing: Theme.Spacing.md) {
                // Retake button
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

                // Use photo button
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

// MARK: - Photo Picker (for Simulator)
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

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Preview
#Preview {
    CameraView()
}
