import SwiftUI

/// Onboarding flow with 3 screens
struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()

    var onComplete: (() -> Void)?

    // MARK: - Onboarding Pages Data
    private let pages: [(imageName: String, title: String, subtitle: String, buttonText: String)] = [
        (
            imageName: "iphone.radiowaves.left.and.right",
            title: "Your phone steals your thoughts",
            subtitle: "Endless attention. Zero reflection.",
            buttonText: "This is the door out."
        ),
        (
            imageName: "pencil.and.scribble",
            title: "This app isn't for typing, it's for writing",
            subtitle: "Do you have a pen and paper?",
            buttonText: "I'm ready to write on paper"
        ),
        (
            imageName: "flame",
            title: "One simple ritual",
            subtitle: "Track your pages. Watch your progress and thoughts grow.",
            buttonText: "Leave the phone alone."
        )
    ]

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                skipButton

                // Page content
                TabView(selection: $viewModel.currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(
                            imageName: pages[index].imageName,
                            title: pages[index].title,
                            subtitle: pages[index].subtitle
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(Theme.Animation.standard, value: viewModel.currentPage)

                // Bottom section with dots and button
                bottomSection
            }
        }
        .onChange(of: viewModel.showPaywall) { _, shouldComplete in
            if shouldComplete {
                onComplete?()
            }
        }
    }

    // MARK: - Skip Button
    private var skipButton: some View {
        HStack {
            Spacer()

            Button {
                viewModel.skip()
            } label: {
                Text("Skip")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(.trailing, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
        }
    }

    // MARK: - Bottom Section
    private var bottomSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Page dots
            pageIndicator

            // Continue button
            Button {
                viewModel.continueAction()
            } label: {
                Text(pages[viewModel.currentPage].buttonText)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .padding(.bottom, Theme.Spacing.xxl)
    }

    // MARK: - Page Indicator
    private var pageIndicator: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            ForEach(0..<viewModel.totalPages, id: \.self) { index in
                Circle()
                    .fill(
                        index == viewModel.currentPage
                            ? Theme.Colors.accent
                            : Theme.Colors.secondaryText.opacity(0.3)
                    )
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == viewModel.currentPage ? 1.2 : 1.0)
                    .animation(Theme.Animation.quick, value: viewModel.currentPage)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView()
}
