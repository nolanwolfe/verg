import SwiftUI

/// Read-only browsing of a finished book's pages
struct BookDetailView: View {
    let book: Book
    @ObservedObject var viewModel: StatsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showFullScreen = false
    @State private var selectedIndex = 0
    @State private var showDeleteConfirmation = false
    @State private var showPaywall = false
    @State private var showCustomize = false

    private let gatingService = SessionGatingService.shared

    private var pages: [Session] {
        viewModel.sessions(for: book)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Book info
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.formattedDateRange)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                            Text("\(pages.count) \(pages.count == 1 ? "page" : "pages")")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText.opacity(0.7))
                        }

                        Spacer()

                        // A little subtitle/memory the user can write about
                        // this book — tapping it (or "+ Add a note") opens
                        // the same sheet used to rename/recolor.
                        Button {
                            showCustomize = true
                        } label: {
                            Group {
                                if book.note.isEmpty {
                                    Text("+ Add a note")
                                        .foregroundColor(Theme.Colors.secondaryText.opacity(0.35))
                                } else {
                                    Text(book.note)
                                        .foregroundColor(Theme.Colors.secondaryText.opacity(0.8))
                                }
                            }
                            .font(.system(size: 12, design: .serif).italic())
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: 170, alignment: .trailing)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)

                    PageGridView(
                        sessions: pages,
                        loadThumbnail: { await viewModel.loadThumbnailAsync(for: $0) },
                        peekThumbnail: { viewModel.cachedThumbnail(for: $0) },
                        onSelect: { session in
                            selectedIndex = pages.firstIndex(where: { $0.id == session.id }) ?? 0
                            showFullScreen = true
                        },
                        isLocked: { !gatingService.canViewPage(dated: $0.date) },
                        onLockedTap: { _ in showPaywall = true },
                        emptyStateMessage: "This book has no pages."
                    )
                }
            }
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            showCustomize = true
                        } label: {
                            Label("Rename & Color", systemImage: "paintpalette")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Book", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.accent)
                }
            }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenImageView(
                sessions: pages,
                initialIndex: selectedIndex,
                loadImage: { await viewModel.loadImageAsync(for: $0) },
                loadThumbnail: { await viewModel.loadThumbnailAsync(for: $0) },
                peekThumbnail: { viewModel.cachedThumbnail(for: $0) },
                onDismiss: { showFullScreen = false },
                allowsDelete: false
            )
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(PurchaseService.shared)
        }
        .sheet(isPresented: $showCustomize) {
            BookCustomizeView(book: book, viewModel: viewModel)
        }
        .confirmationDialog(
            "Delete this book?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Book", role: .destructive) {
                viewModel.deleteBook(book)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Pages return to your current journal.")
        }
    }
}

// MARK: - Book Cover
struct BookCoverView: View {
    let book: Book

    /// Cover color presets, indexed by book.colorIndex. Entry 0 is the
    /// original warm leather; the rest are user-selectable in
    /// BookCustomizeView.
    static let palette: [Color] = [
        Color(hex: "8B3A0F"), // leather (default)
        Color(hex: "6B4A1F"), // walnut
        Color(hex: "7A2E3D"), // oxblood
        Color(hex: "3E5641"), // forest
        Color(hex: "44415C"), // indigo
        Color(hex: "2E2E30"), // charcoal
        Color(hex: "8A6D3B")  // gold-leaf tan
    ]

    var coverColor: Color {
        Self.palette[abs(book.colorIndex) % Self.palette.count]
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [coverColor, coverColor.opacity(0.35)],
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
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
                    )

                VStack(spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.7)
                        .frame(maxHeight: 34)

                    Text("\(book.pageCount) \(book.pageCount == 1 ? "page" : "pages")")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.horizontal, 8)
                // Pin this to the cover's own width — without it, a long
                // unbroken title can widen the ZStack past the rectangle
                // beneath it and spill text over the cover's border.
                .frame(width: 90)
            }
            .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)

            Text(book.formattedDateRange)
                .font(.system(size: 9))
                .foregroundColor(Theme.Colors.secondaryText.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 90)
        }
    }
}

// MARK: - Book Customize Sheet
/// Rename a book and choose its cover color.
struct BookCustomizeView: View {
    /// Local mutable copy so edits feel live; committed through the
    /// view model on change.
    @State var book: Book
    @ObservedObject var viewModel: StatsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var note: String = ""
    @State private var colorIndex: Int = 0

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: Theme.Spacing.xl) {
                    // Live preview of the cover
                    HStack {
                        Spacer()
                        previewCover
                        Spacer()
                    }
                    .padding(.top, Theme.Spacing.xl)

                    // Title field
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("TITLE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.Colors.secondaryText)
                        TextField("Title", text: $title)
                            .font(Theme.Typography.body)
                            .textFieldStyle(.plain)
                            .padding(Theme.Spacing.sm)
                            .background(Theme.Colors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .onChange(of: title) { _, newValue in
                                commitTitle(newValue)
                            }
                    }

                    // Note field — a short memory, shown beside the date range
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("MEMORY")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.Colors.secondaryText)
                        TextField("A line to remember this one by", text: $note)
                            .font(Theme.Typography.body)
                            .textFieldStyle(.plain)
                            .padding(Theme.Spacing.sm)
                            .background(Theme.Colors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .onChange(of: note) { _, newValue in
                                commitNote(newValue)
                            }
                    }

                    // Color picker
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("COVER COLOR")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.Colors.secondaryText)

                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach(BookCoverView.palette.indices, id: \.self) { index in
                                Button {
                                    colorIndex = index
                                    viewModel.setBookColor(book, colorIndex: index)
                                    book.colorIndex = index
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(BookCoverView.palette[index])
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                            )

                                        if colorIndex == index {
                                            Circle()
                                                .strokeBorder(Theme.Colors.accent, lineWidth: 2)
                                                .frame(width: 44, height: 44)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.accent)
                }
            }
        }
        .onAppear {
            title = book.title
            note = book.note
            colorIndex = book.colorIndex
        }
    }

    private func commitTitle(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        viewModel.renameBook(book, to: trimmed)
        book.title = trimmed
    }

    private func commitNote(_ newValue: String) {
        viewModel.setBookNote(book, note: newValue)
        book.note = newValue
    }

    private var previewCover: some View {
        BookCoverView(book: book)
    }
}

// MARK: - Preview
#Preview {
    BookDetailView(
        book: Book(
            title: "Journal 1",
            startDate: Date(),
            endDate: Date(),
            sessionIDs: [],
            coverStyle: 0
        ),
        viewModel: StatsViewModel()
    )
}
