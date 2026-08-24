import SwiftUI

/// Journal tab — just the current journal. Finished books live on the
/// Library tab; this screen is one thing: your pages, in order.
struct JournalView: View {
    @StateObject private var viewModel = StatsViewModel()
    @EnvironmentObject private var purchaseService: PurchaseService

    @State private var showFinishAlert = false
    @State private var newBookTitle = ""
    /// The locked page that sent someone to the paywall, carried *with* the
    /// presentation. A `Date?` set alongside a separate boolean is the same
    /// trap the page viewer fell into: the two are assigned together but are
    /// not applied atomically, so the cover could be built before the date
    /// landed and the paywall fell back to its generic line instead of
    /// naming the page they reached for.
    @State private var lockedPage: LockedPage?

    private struct LockedPage: Identifiable {
        let date: Date
        var id: TimeInterval { date.timeIntervalSince1970 }
    }
    /// Presented with `item:` so the starting page cannot be lost between
    /// setting the index and raising a separate boolean — see `ViewerStart`.
    @State private var viewerStart: ViewerStart?

    private let gatingService = SessionGatingService.shared

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection

                PageGridView(
                    sessions: viewModel.currentSessions,
                    loadThumbnail: { await viewModel.loadThumbnailAsync(for: $0) },
                    peekThumbnail: { viewModel.cachedThumbnail(for: $0) },
                    onSelect: { session in
                        guard let index = viewModel.currentSessions
                            .firstIndex(where: { $0.id == session.id }) else { return }
                        viewerStart = ViewerStart(index: index)
                    },
                    isLocked: { !gatingService.canViewPage(dated: $0.date) },
                    onLockedTap: { session in
                        lockedPage = LockedPage(date: session.date)
                    },
                    emptyStateMessage: viewModel.books.isEmpty
                        ? "Complete a writing session to capture your first page"
                        : "Fresh journal — complete a session to add your first page"
                )
            }
        }
        .fullScreenCover(item: $viewerStart) { start in
            FullScreenImageView(
                sessions: viewModel.currentSessions,
                initialIndex: start.index,
                loadImage: { await viewModel.loadImageAsync(for: $0) },
                loadThumbnail: { await viewModel.loadThumbnailAsync(for: $0) },
                peekThumbnail: { viewModel.cachedThumbnail(for: $0) },
                onDismiss: { viewerStart = nil },
                onDelete: { session in
                    viewModel.deleteSession(session)
                }
            )
        }
        .fullScreenCover(item: $lockedPage) { page in
            PaywallView(lockedPageDate: page.date)
                .environmentObject(purchaseService)
        }
        .alert("Finish this journal?", isPresented: $showFinishAlert) {
            TextField("Journal \(viewModel.books.count + 1)", text: $newBookTitle)
            Button("Finish") {
                viewModel.finishCurrentJournal(title: newBookTitle)
                newBookTitle = ""
                AudioService.shared.playHaptic(.success)
            }
            Button("Cancel", role: .cancel) {
                newBookTitle = ""
            }
        } message: {
            Text("Your \(viewModel.currentSessions.count) pages become a book, and a fresh journal begins.")
        }
        .onAppear {
            DispatchQueue.main.async {
                viewModel.refresh()
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Journal")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.primaryText)

                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }

            Spacer()

            if !viewModel.currentSessions.isEmpty {
                Button {
                    showFinishAlert = true
                } label: {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Theme.Colors.accent)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Finish this journal and archive it as a book")
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.xs)
    }

    private var subtitle: String {
        let count = viewModel.currentSessions.count
        guard count > 0 else { return "Nothing written yet." }
        return "\(count) \(count == 1 ? "page" : "pages") in this journal."
    }
}

// MARK: - Preview
#Preview {
    JournalView()
}
