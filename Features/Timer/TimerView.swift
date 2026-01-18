import SwiftUI

/// Full-screen timer view with animated candle
struct TimerView: View {
    @StateObject private var viewModel = TimerViewModel()
    @Environment(\.dismiss) private var dismiss

    var onComplete: (() -> Void)?

    var body: some View {
        ZStack {
            // Pure black background
            Color.black
                .ignoresSafeArea()

            VStack {
                // Cancel button (subtle, top-left)
                cancelButton

                Spacer()

                // Animated candle
                CandleView(
                    progress: viewModel.progress,
                    isBurning: viewModel.isRunning
                )

                Spacer()
                    .frame(height: Theme.Spacing.xxl)

                // Time remaining
                timeDisplay

                Spacer()
            }
        }
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            CameraView(
                duration: viewModel.totalDuration,
                onPhotoSaved: {
                    viewModel.onPhotoSaved()
                },
                onCancel: {
                    viewModel.showCamera = false
                    dismiss()
                    onComplete?()
                }
            )
        }
        .onAppear {
            viewModel.onComplete = {
                dismiss()
                onComplete?()
            }
            viewModel.startTimer()
        }
        .onDisappear {
            viewModel.stopTimer()
        }
        .statusBar(hidden: true)
    }

    // MARK: - Cancel Button
    private var cancelButton: some View {
        HStack {
            Button {
                viewModel.cancelSession()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.Colors.secondaryText.opacity(0.5))
                    .frame(width: 44, height: 44)
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Time Display
    private var timeDisplay: some View {
        Text(viewModel.formattedTime)
            .font(Theme.Typography.timerDisplay)
            .foregroundColor(Theme.Colors.primaryText.opacity(0.8))
            .monospacedDigit()
    }
}

// MARK: - Preview
#Preview {
    TimerView()
}
