import SwiftUI

/// Read-only browsing of a finished book's pages
struct BookDetailView: View {
    let book: Book
    @ObservedObject var viewModel: StatsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showFullScreen = false
    @State private var selectedIndex = 0
    @State private var showDeleteConfirmation = false

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
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.formattedDateRange)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                            Text("\(pages.count) \(pages.count == 1 ? "page" : "pages")")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText.opacity(0.7))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)

                    PageGridView(
                        sessions: pages,
                        loadThumbnail: { await viewModel.loadThumbnailAsync(for: $0) },
                        onSelect: { session in
                            selectedIndex = pages.firstIndex(where: { $0.id == session.id }) ?? 0
                            showFullScreen = true
                        },
                        emptyStateMessage: "This book has no pages."
                    )
                }
            }
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
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
                onDismiss: { showFullScreen = false },
                allowsDelete: false
            )
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
