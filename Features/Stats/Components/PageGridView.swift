import SwiftUI
import UIKit

/// Grid view of captured journal pages
struct PageGridView: View {
    let sessions: [Session]
    let getImage: (Session) -> UIImage?
    let onSelect: (Session) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.xxs),
        GridItem(.flexible(), spacing: Theme.Spacing.xxs),
        GridItem(.flexible(), spacing: Theme.Spacing.xxs)
    ]

    var body: some View {
        if sessions.isEmpty {
            emptyState
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.xxs) {
                    ForEach(sessions) { session in
                        PageThumbnail(
                            session: session,
                            image: getImage(session),
                            onTap: { onSelect(session) }
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()

            Image(systemName: "doc.text.image")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.secondaryText.opacity(0.5))

            Text("No pages yet")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.secondaryText)

            Text("Complete a writing session to capture your first page")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
        }
    }
}

// MARK: - Page Thumbnail
struct PageThumbnail: View {
    let session: Session
    let image: UIImage?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Theme.Colors.cardBackground)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(Theme.Colors.secondaryText)
                        )
                }
            }
            .cornerRadius(Theme.CornerRadius.small)
        }
    }
}

// MARK: - Full Screen Image View
struct FullScreenImageView: View {
    let session: Session
    let image: UIImage?
    let onDismiss: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // Image
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
            }

            // Overlay controls
            VStack {
                // Header
                HStack {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.Colors.primaryText)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.Colors.primaryText)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)

                Spacer()

                // Footer with date info
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                        Text(session.formattedDate)
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.primaryText)

                        Text("\(session.formattedTime) • \(session.formattedDuration)")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }

                    Spacer()
                }
                .padding(Theme.Spacing.md)
                .background(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .confirmationDialog(
            "Delete this page?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
                onDismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - Preview
#Preview {
    PageGridView(
        sessions: [],
        getImage: { _ in nil },
        onSelect: { _ in }
    )
    .background(Theme.Colors.background)
}
