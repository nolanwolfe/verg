import SwiftUI

/// Journal tab — the current journal's pages plus finished books
struct JournalView: View {
    @StateObject private var viewModel = StatsViewModel()
    @EnvironmentObject private var purchaseService: PurchaseService

    @State private var showFinishAlert = false
    @State private var newBookTitle = ""
    @State private var selectedBook: Book?
    @State private var showPaywall = false

    private let gatingService = SessionGatingService.shared

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection

                if !viewModel.books.isEmpty {
                    booksShelf
                }

                PageGridView(
                    sessions: viewModel.currentSessions,
                    loadThumbnail: { await viewModel.loadThumbnailAsync(for: $0) },
                    peekThumbnail: { viewModel.cachedThumbnail(for: $0) },
                    onSelect: { viewModel.selectSession($0, in: viewModel.currentSessions) },
                    isLocked: { !gatingService.canViewPage(dated: $0.date) },
                    onLockedTap: { _ in showPaywall = true },
                    emptyStateMessage: viewModel.books.isEmpty
                        ? "Complete a writing session to capture your first page"
                        : "Fresh journal — complete a session to add your first page"
                )
            }
        }
        .fullScreenCover(isPresented: $viewModel.showFullScreenImage) {
            FullScreenImageView(
                sessions: viewModel.currentSessions,
                initialIndex: viewModel.selectedSessionIndex,
                loadImage: { await viewModel.loadImageAsync(for: $0) },
                loadThumbnail: { await viewModel.loadThumbnailAsync(for: $0) },
                peekThumbnail: { viewModel.cachedThumbnail(for: $0) },
                onDismiss: {
                    viewModel.showFullScreenImage = false
                    viewModel.selectedSession = nil
                },
                onDelete: { session in
                    viewModel.deleteSession(session)
                }
            )
        }
        .sheet(item: $selectedBook) { book in
            BookDetailView(book: book, viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
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
        HStack {
            Text("Your Pages")
                .font(Theme.Typography.title)
                .foregroundColor(Theme.Colors.primaryText)

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
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.xs)
    }

    // MARK: - Books Shelf
    private var booksShelf: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Books")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
                .padding(.horizontal, Theme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(viewModel.books) { book in
                        Button {
                            selectedBook = book
                        } label: {
                            BookCoverView(book: book)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
        .padding(.bottom, Theme.Spacing.sm)
    }
}

// MARK: - Book Cover
struct BookCoverView: View {
    let book: Book

    /// Warm, dark gradient presets — indexed by book.coverStyle
    private static let coverGradients: [[Color]] = [
        [Color(hex: "8B3A0F"), Color(hex: "3D1A06")],
        [Color(hex: "6B4A1F"), Color(hex: "2E2008")],
        [Color(hex: "7A2E3D"), Color(hex: "331018")],
        [Color(hex: "3E5641"), Color(hex: "16241A")],
        [Color(hex: "44415C"), Color(hex: "1B1A28")]
    ]

    private var gradientColors: [Color] {
        Self.coverGradients[book.coverStyle % Self.coverGradients.count]
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 120)
                    .overlay(
                        // Spine highlight
                        HStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 4)
                            Spacer()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
                    )

                VStack(spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)

                    Text("\(book.pageCount) \(book.pageCount == 1 ? "page" : "pages")")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.horizontal, 8)
            }
            .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)

            Text(book.formattedDateRange)
                .font(.system(size: 9))
                .foregroundColor(Theme.Colors.secondaryText.opacity(0.7))
                .lineLimit(1)
        }
    }
}

// MARK: - Preview
#Preview {
    JournalView()
}
