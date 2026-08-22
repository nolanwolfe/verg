import SwiftUI
import UIKit

/// Grid view of captured journal pages
struct PageGridView: View {
    let sessions: [Session]
    let loadThumbnail: (Session) async -> UIImage?
    var peekThumbnail: (Session) -> UIImage? = { _ in nil }
    let onSelect: (Session) -> Void
    /// Pages outside the free archive window are never hidden or deleted —
    /// they still render (dimmed, with a lock badge) so the user can see
    /// their page still exists; tapping prompts Ascent instead of opening it.
    var isLocked: (Session) -> Bool = { _ in false }
    var onLockedTap: (Session) -> Void = { _ in }
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
                        let locked = isLocked(session)
                        PageThumbnail(
                            session: session,
                            loadThumbnail: loadThumbnail,
                            peekThumbnail: peekThumbnail,
                            isLocked: locked,
                            onTap: locked ? { onLockedTap(session) } : { onSelect(session) }
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
    var peekThumbnail: (Session) -> UIImage? = { _ in nil }
    var isLocked: Bool = false
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
                        .opacity(isLocked ? 0.35 : 1)
                } else {
                    Rectangle()
                        .fill(Theme.Colors.cardBackground)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(Theme.Colors.secondaryText.opacity(0.4))
                        )
                }

                if isLocked {
                    Color.black.opacity(0.25)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .cornerRadius(Theme.CornerRadius.small)
        }
        .task(id: session.id) {
            // Cached thumbnails render on the first frame; only cache misses
            // take the async path
            if image == nil, let cached = peekThumbnail(session) {
                image = cached
                return
            }
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
    let peekThumbnail: (Session) -> UIImage?
    let onDismiss: () -> Void
    let onDelete: (Session) -> Void
    let allowsDelete: Bool

    @State private var showDeleteConfirmation = false
    @State private var dismissDragProgress: CGFloat = 0

    init(
        sessions: [Session],
        initialIndex: Int,
        loadImage: @escaping (Session) async -> UIImage?,
        loadThumbnail: @escaping (Session) async -> UIImage?,
        peekThumbnail: @escaping (Session) -> UIImage? = { _ in nil },
        onDismiss: @escaping () -> Void,
        onDelete: @escaping (Session) -> Void = { _ in },
        allowsDelete: Bool = true
    ) {
        self._sessions = State(initialValue: sessions)
        self._currentIndex = State(initialValue: min(initialIndex, max(0, sessions.count - 1)))
        self.loadImage = loadImage
        self.loadThumbnail = loadThumbnail
        self.peekThumbnail = peekThumbnail
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
            Color.black.opacity(1 - dismissDragProgress * 0.6).ignoresSafeArea()

            // Swipeable pages. A paged TabView is NOT lazy — every page view
            // in the ForEach is built when the viewer opens. With 100+ pages
            // that meant 100+ image-loading tasks firing at once, so only
            // pages within the swipe window get real content; the rest are
            // empty placeholders that can never be seen mid-swipe anyway.
            TabView(selection: $currentIndex) {
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    Group {
                        if abs(index - currentIndex) <= 2 {
                            FullScreenPageView(
                                session: session,
                                isNearCurrent: abs(index - currentIndex) <= 1,
                                loadImage: loadImage,
                                loadThumbnail: loadThumbnail,
                                peekThumbnail: peekThumbnail,
                                onDismiss: onDismiss,
                                onDragProgressChanged: { dismissDragProgress = $0 }
                            )
                        } else {
                            Color.black
                        }
                    }
                    .ignoresSafeArea()
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Overlay — fades out while dragging to dismiss so it doesn't
            // sit on top of the photo mid-gesture
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
            .opacity(1 - dismissDragProgress)
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
    var peekThumbnail: (Session) -> UIImage? = { _ in nil }
    var onDismiss: () -> Void = {}
    var onDragProgressChanged: (CGFloat) -> Void = { _ in }

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
                ZoomableImageView(
                    image: image,
                    onDismiss: onDismiss,
                    onDragProgressChanged: onDragProgressChanged
                )
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .task(id: LoadKey(id: session.id, near: isNearCurrent)) {
            if isNearCurrent {
                // Show the already-decoded grid thumbnail immediately while
                // the full-res decode happens off-main
                if image == nil {
                    image = peekThumbnail(session)
                }
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
