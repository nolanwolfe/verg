import SwiftUI

/// Journal tab — the user's captured pages
struct JournalView: View {
    @StateObject private var viewModel = StatsViewModel()

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection

                PageGridView(
                    sessions: viewModel.sessions,
                    loadThumbnail: { await viewModel.loadThumbnailAsync(for: $0) },
                    onSelect: { viewModel.selectSession($0) }
                )
            }
        }
        .fullScreenCover(isPresented: $viewModel.showFullScreenImage) {
            FullScreenImageView(
                sessions: viewModel.sessions,
                initialIndex: viewModel.selectedSessionIndex,
                loadImage: { await viewModel.loadImageAsync(for: $0) },
                loadThumbnail: { await viewModel.loadThumbnailAsync(for: $0) },
                onDismiss: {
                    viewModel.showFullScreenImage = false
                    viewModel.selectedSession = nil
                },
                onDelete: { session in
                    viewModel.deleteSession(session)
                }
            )
        }
        .onAppear {
            DispatchQueue.main.async {
                viewModel.refresh()
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        Text("Your Pages")
            .font(Theme.Typography.title)
            .foregroundColor(Theme.Colors.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.md)
    }
}

// MARK: - Preview
#Preview {
    JournalView()
}
