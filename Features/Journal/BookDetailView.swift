import SwiftUI

/// Read-only browsing of a finished book's pages
struct BookDetailView: View {
    let book: Book
    @ObservedObject var viewModel: StatsViewModel
    @Environment(\.dismiss) private var dismiss

    /// The page the viewer should open on, carried *with* the presentation.
    ///
    /// This used to be a separate `selectedIndex` alongside a boolean
    /// `showFullScreen`. Setting the two together is not atomic as far as the
    /// presentation machinery is concerned: the cover could be built while
    /// the index was still its initial 0, so tapping any page opened the
    /// first one. An `item:` presentation cannot come apart that way — the
    /// index is the thing being presented.
    @State private var viewerStart: ViewerStart?
    @State private var showDeleteConfirmation = false
    @State private var showPaywall = false
    @State private var showCustomize = false

    private let gatingService = SessionGatingService.shared

    private var pages: [Session] {
        viewModel.sessions(for: book)
    }

    // MARK: - Book Info Header
    /// The date and the note, each hung on one of the two seams between the
    /// three columns of pages below.
    ///
    /// Not thirds by eye: the grid is three equal columns separated by two
    /// `xxs` gutters, so a seam's centre is at `column + gutter/2`, and that
    /// is what is computed here from the same width the grid gets. Guessing
    /// 33%/67% is close but visibly off once the gutters are accounted for,
    /// and the whole point of the arrangement is that the two labels line up
    /// with something.
    private var bookInfoHeader: some View {
        GeometryReader { geo in
            let gutter = Theme.Spacing.xxs
            let column = (geo.size.width - gutter * 2) / 3
            let firstSeam = column + gutter / 2
            let secondSeam = column * 2 + gutter * 1.5
            let slot = column + gutter

            dateBlock
                .frame(width: slot)
                .position(x: firstSeam, y: geo.size.height / 2)

            noteBlock
                .frame(width: slot)
                .position(x: secondSeam, y: geo.size.height / 2)
        }
        // Two lines of caption plus breathing room. Fixed because
        // GeometryReader has no intrinsic height of its own.
        .frame(height: 38)
    }

    private var dateBlock: some View {
        VStack(spacing: 1) {
            Text(book.formattedDateRange)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
            Text("\(pages.count) \(pages.count == 1 ? "page" : "pages")")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText.opacity(0.7))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .multilineTextAlignment(.center)
    }

    /// A little subtitle/memory the user can write about this book — tapping
    /// it (or "+ Add a note") opens the same sheet used to rename/recolor.
    private var noteBlock: some View {
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
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    bookInfoHeader
                        // Same gutter as the grid below, so the two share a
                        // coordinate space and the seams line up.
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)

                    PageGridView(
                        sessions: pages,
                        loadThumbnail: { await viewModel.loadThumbnailAsync(for: $0) },
                        peekThumbnail: { viewModel.cachedThumbnail(for: $0) },
                        onSelect: { session in
                            guard let index = pages.firstIndex(where: { $0.id == session.id }) else { return }
                            viewerStart = ViewerStart(index: index)
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
        .fullScreenCover(item: $viewerStart) { start in
            FullScreenImageView(
                sessions: pages,
                initialIndex: start.index,
                loadImage: { await viewModel.loadImageAsync(for: $0) },
                loadThumbnail: { await viewModel.loadThumbnailAsync(for: $0) },
                peekThumbnail: { viewModel.cachedThumbnail(for: $0) },
                onDismiss: { viewerStart = nil },
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

    /// Cover color presets, indexed by book.colorIndex.
    ///
    /// Order is load-bearing: entry 0 is the original warm leather and the
    /// next six are the muted bindings that shipped first, so every book
    /// already on someone's shelf keeps exactly the cover it had. The full
    /// spectrum is appended after them — a shelf should look like a shelf,
    /// and that means the person choosing gets real colors, not six browns.
    ///
    /// Each is a mid-saturation value rather than a pure hue: covers render
    /// as a gradient down to 35% opacity on black, and neon reads as plastic
    /// at that treatment.
    static let palette: [Color] = [
        // Original bindings
        Color(hex: "8B3A0F"), // leather (default)
        Color(hex: "6B4A1F"), // walnut
        Color(hex: "7A2E3D"), // oxblood
        Color(hex: "3E5641"), // forest
        Color(hex: "44415C"), // indigo
        Color(hex: "2E2E30"), // charcoal
        Color(hex: "8A6D3B"), // gold-leaf tan
        // Spectrum
        Color(hex: "C0392B"), // red
        Color(hex: "D35400"), // orange
        Color(hex: "E0A81C"), // amber
        Color(hex: "7A9A2E"), // olive
        Color(hex: "2E8B57"), // green
        Color(hex: "14837B"), // teal
        Color(hex: "1B7FA8"), // cyan
        Color(hex: "2C5FA8"), // blue
        Color(hex: "5B4BA8"), // violet
        Color(hex: "7B3FA0"), // purple
        Color(hex: "A8317E"), // magenta
        Color(hex: "C0396B"), // rose
        // Neutrals
        Color(hex: "55606B"), // slate
        Color(hex: "B9AFA0")  // bone
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

                        // A wrapping grid, not a row: the palette is the full
                        // spectrum now and a single HStack would run off the
                        // side of the screen. The cell is 44pt so the whole
                        // swatch is a comfortable target.
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 44), spacing: Theme.Spacing.xs)],
                            spacing: Theme.Spacing.xs
                        ) {
                            ForEach(BookCoverView.palette.indices, id: \.self) { index in
                                Button {
                                    AudioService.shared.playUITick()
                                    colorIndex = index
                                    viewModel.setBookColor(book, colorIndex: index)
                                    book.colorIndex = index
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(BookCoverView.palette[index])
                                            .frame(width: 34, height: 34)
                                            .overlay(
                                                Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                            )

                                        if colorIndex == index {
                                            Circle()
                                                .strokeBorder(Theme.Colors.accent, lineWidth: 2)
                                                .frame(width: 43, height: 43)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Cover color \(index + 1) of \(BookCoverView.palette.count)")
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
