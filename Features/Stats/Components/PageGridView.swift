import SwiftUI
import UIKit

/// Grid view of captured journal pages
struct PageGridView: View {
    let sessions: [Session]
    let loadThumbnail: (Session) async -> UIImage?
    let onSelect: (Session) -> Void
    var emptyStateMessage: String = "Complete a writing session to capture your first page"

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
                            loadThumbnail: loadThumbnail,
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

            Text(emptyStateMessage)
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
    let loadThumbnail: (Session) async -> UIImage?
    let onTap: () -> Void

    @State private var image: UIImage?

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
                                .foregroundColor(Theme.Colors.secondaryText.opacity(0.4))
                        )
                }
            }
            .cornerRadius(Theme.CornerRadius.small)
        }
        .task(id: session.id) {
            image = await loadThumbnail(session)
        }
    }
}

// MARK: - Full Screen Image View (swipeable)
struct FullScreenImageView: View {
    @State private var sessions: [Session]
    @State private var currentIndex: Int
    let loadImage: (Session) async -> UIImage?
    let loadThumbnail: (Session) async -> UIImage?
    let onDismiss: () -> Void
    let onDelete: (Session) -> Void
    let allowsDelete: Bool

    @State private var showDeleteConfirmation = false

    init(
        sessions: [Session],
        initialIndex: Int,
        loadImage: @escaping (Session) async -> UIImage?,
        loadThumbnail: @escaping (Session) async -> UIImage?,
        onDismiss: @escaping () -> Void,
        onDelete: @escaping (Session) -> Void = { _ in },
        allowsDelete: Bool = true
    ) {
        self._sessions = State(initialValue: sessions)
        self._currentIndex = State(initialValue: min(initialIndex, max(0, sessions.count - 1)))
        self.loadImage = loadImage
        self.loadThumbnail = loadThumbnail
        self.onDismiss = onDismiss
        self.onDelete = onDelete
        self.allowsDelete = allowsDelete
    }

    private var currentSession: Session? {
        guard !sessions.isEmpty, currentIndex < sessions.count else { return nil }
        return sessions[currentIndex]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Swipeable pages — full-res only near the current index
            TabView(selection: $currentIndex) {
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    FullScreenPageView(
                        session: session,
                        isNearCurrent: abs(index - currentIndex) <= 1,
                        loadImage: loadImage,
                        loadThumbnail: loadThumbnail
                    )
                    .ignoresSafeArea()
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Overlay
            VStack {
                // Top bar
                HStack {
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Spacer()

                    if sessions.count > 1 {
                        Text("\(currentIndex + 1) / \(sessions.count)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.black.opacity(0.4)))
                    }

                    Spacer()

                    if allowsDelete {
                        Button { showDeleteConfirmation = true } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)

                Spacer()

                // Bottom info
                if let session = currentSession {
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                            Text(session.formattedDate)
                                .font(Theme.Typography.headline)
                                .foregroundColor(.white)
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
        }
        .confirmationDialog(
            "Delete this page?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let session = currentSession else { return }
                onDelete(session)
                sessions.remove(at: currentIndex)
                if sessions.isEmpty {
                    onDismiss()
                } else {
                    currentIndex = min(currentIndex, sessions.count - 1)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - Full Screen Page
/// One page of the fullscreen viewer. Loads the full-resolution image only
/// while it is the current page or an immediate neighbor; distant pages show
/// the (cheap, cached) thumbnail so opening the viewer stays fast at any count.
private struct FullScreenPageView: View {
    let session: Session
    let isNearCurrent: Bool
    let loadImage: (Session) async -> UIImage?
    let loadThumbnail: (Session) async -> UIImage?

    @State private var image: UIImage?
    @State private var hasFullRes = false

    private struct LoadKey: Equatable {
        let id: UUID
        let near: Bool
    }

    var body: some View {
        ZStack {
            Color.black
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .task(id: LoadKey(id: session.id, near: isNearCurrent)) {
            if isNearCurrent {
                if !hasFullRes, let full = await loadImage(session) {
                    image = full
                    hasFullRes = true
                }
            } else {
                // Downgrade distant pages to the cached thumbnail so memory
                // stays bounded (~3 full-res images) however far the user swipes.
                if hasFullRes || image == nil {
                    image = await loadThumbnail(session) ?? image
                    hasFullRes = false
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    PageGridView(
        sessions: [],
        loadThumbnail: { _ in nil },
        onSelect: { _ in }
    )
    .background(Theme.Colors.background)
}
