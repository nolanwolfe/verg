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
    /// The "On this day" page, opened on its own (it may be in a book, so it
    /// is not necessarily in `currentSessions`).
    @State private var onThisDayPage: Session?

    private let gatingService = SessionGatingService.shared

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection

                if let match = OnThisDay.find(in: viewModel.sessions) {
                    OnThisDayCard(
                        match: match,
                        isLocked: !gatingService.canViewPage(dated: match.session.date),
                        loadThumbnail: { await viewModel.loadThumbnailAsync(for: $0) }
                    ) {
                        if gatingService.canViewPage(dated: match.session.date) {
                            onThisDayPage = match.session
                        } else {
                            lockedPage = LockedPage(date: match.session.date)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.sm)
                }

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
                },
                isLocked: { !gatingService.canViewPage(dated: $0.date) },
                onLockedTap: { session in
                    viewerStart = nil
                    lockedPage = LockedPage(date: session.date)
                }
            )
        }
        .fullScreenCover(item: $onThisDayPage) { page in
            FullScreenImageView(
                sessions: [page],
                initialIndex: 0,
                loadImage: { await viewModel.loadImageAsync(for: $0) },
                loadThumbnail: { await viewModel.loadThumbnailAsync(for: $0) },
                peekThumbnail: { viewModel.cachedThumbnail(for: $0) },
                onDismiss: { onThisDayPage = nil },
                allowsDelete: false,
                isLocked: { !gatingService.canViewPage(dated: $0.date) },
                onLockedTap: { session in
                    onThisDayPage = nil
                    lockedPage = LockedPage(date: session.date)
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

// MARK: - On This Day Card

/// One quiet row above the grid: a page from this day a year or a month ago.
/// For a page outside the free window the thumbnail stays hidden and the
/// row says the page is still here, the same promise the locked grid makes.
private struct OnThisDayCard: View {
    let match: OnThisDay.Match
    let isLocked: Bool
    let loadThumbnail: (Session) async -> UIImage?
    let onTap: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.Colors.cardBackground)
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Colors.accent)
                    } else if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(width: 48, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(match.label)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)
                    Text(isLocked
                         ? "This page is still here. The Golden Age opens it."
                         : match.session.date.formatted(date: .long, time: .omitted))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
            .padding(Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.Colors.accent.opacity(0.35), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("journal.onThisDay")
        .task(id: match.session.id) {
            // A locked page is never decoded, as in the grid.
            guard !isLocked else { thumbnail = nil; return }
            thumbnail = await loadThumbnail(match.session)
        }
    }
}

// MARK: - Preview
#Preview {
    JournalView()
}
