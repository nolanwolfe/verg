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
    /// their page still exists; tapping prompts The Golden Age instead of opening it.
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
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
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

// MARK: - Viewer Presentation
/// Which page the fullscreen viewer opens on.
///
/// Exists so the viewer is presented with `.fullScreenCover(item:)` rather
/// than a boolean plus a separate index. Those two pieces of state are set in
/// the same closure but are not applied atomically from the presentation's
/// point of view, and the cover could be built before the index landed —
/// which opened the first page no matter which one was tapped.
struct ViewerStart: Identifiable {
    let index: Int
    var id: Int { index }
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
                    // Always the same view type per page. This used to swap
                    // between FullScreenPageView and a plain Color.black as
                    // the window slid, which changed each page's identity on
                    // every swipe: SwiftUI tore the page down and rebuilt it,
                    // losing its already-decoded @State image and flashing a
                    // placeholder mid-swipe. The window is now a parameter,
                    // so identity is stable and only the content it holds
                    // changes.
                    FullScreenPageView(
                        session: session,
                        // Hold on to a page's picture well past the two
                        // neighbours that can be on screen. Releasing at ±2
                        // meant a fast flick outran the window: pages were
                        // blanked and had to re-decode as they came back, so
                        // swiping quickly flashed empty frames. Only the
                        // immediate neighbours carry a full-resolution decode;
                        // the rest of this window is cheap thumbnails.
                        isWindowed: abs(index - currentIndex) <= 5,
                        isNearCurrent: abs(index - currentIndex) <= 1,
                        loadImage: loadImage,
                        loadThumbnail: loadThumbnail,
                        peekThumbnail: peekThumbnail,
                        onDismiss: onDismiss,
                        onDragProgressChanged: { dismissDragProgress = $0 }
                    )
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

                            // What the page was written to, when there was
                            // one. Pages saved before prompts existed, and
                            // pages written with no prompt, simply omit it.
                            if let prompt = session.prompt, !prompt.isEmpty {
                                Text(prompt)
                                    .font(Theme.Typography.caption.italic())
                                    .foregroundColor(Theme.Colors.secondaryText.opacity(0.85))
                                    .lineLimit(2)
                                    .padding(.top, 2)
                            }
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
        // A photo viewer is dark everywhere — Photos, Files, Messages. The
        // page is the only thing meant to be lit here, in either appearance.
        .preferredColorScheme(.dark)
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
    /// Within the swipe window. Outside it the page holds no image at all,
    /// which is what keeps memory bounded however far the user swipes.
    let isWindowed: Bool
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
        let windowed: Bool
        let near: Bool
    }

    var body: some View {
        ZStack {
            Color.black
            if let image = image {
                ZoomableImageView(
                    image: image,
                    pageID: session.id,
                    onDismiss: onDismiss,
                    onDragProgressChanged: onDragProgressChanged
                )
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .task(id: LoadKey(id: session.id, windowed: isWindowed, near: isNearCurrent)) {
            guard isWindowed else {
                // Outside the window: release the image. Nothing is on screen
                // here, and this is what bounds memory across a long journal.
                image = nil
                hasFullRes = false
                return
            }

            if isNearCurrent {
                // Show the already-decoded grid thumbnail immediately while
                // the full-res decode happens off-main
                if image == nil {
                    image = peekThumbnail(session)
                }

                // Settle before decoding. Flicking through a long journal
                // drags this page in and out of the sharp window several
                // times a second, and each pass used to queue a full-
                // resolution decode of a multi-megapixel photo — work that
                // was obsolete before it finished, and the reason paging felt
                // worse the more pages a book had. `.task(id:)` cancels this
                // sleep the moment the window moves on, so a page swiped past
                // never starts a decode at all.
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled else { return }

                if !hasFullRes, let full = await loadImage(session) {
                    guard !Task.isCancelled else { return }
                    image = full
                    hasFullRes = true
                }
            } else if image == nil {
                // Just outside the sharp window but still in the swipe
                // window: make sure there is *something* to show so the page
                // never slides in empty. A page that already decoded its
                // full-res image keeps it — this used to overwrite it with a
                // thumbnail the moment it fell out of the near window, so
                // swiping back and forth visibly dropped each page to blurry
                // and then popped it sharp again.
                if let cached = peekThumbnail(session) {
                    image = cached
                } else {
                    image = await loadThumbnail(session)
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
