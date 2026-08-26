import Foundation

/// Single source of truth for every URL the app opens.
///
/// These were hardcoded at six call sites — two in Settings, two on the
/// paywall, and the site link in the footer — which is how they drifted:
/// the legal pages moved to `verg.app` when the site went up, and five of
/// the six kept pointing at the old `nolanwolfe.github.io/verg/...`
/// addresses. Those still resolve, but only by way of a redirect that
/// lands on `http://` before Cloudflare upgrades it, so the app was
/// sending people through an unencrypted hop to read the privacy policy.
///
/// The apex is canonical. `www.verg.app` redirects to it, so linking to
/// `www` costs a round trip and buys nothing.
///
/// The trailing slash is deliberate: the site is a directory of
/// `index.html` files, and `/privacy` 301s to `/privacy/`. Naming the
/// real address skips that hop too.
enum Links {
    static let site = URL(string: "https://verg.app")!
    static let privacy = URL(string: "https://verg.app/privacy/")!
    static let terms = URL(string: "https://verg.app/terms/")!
    static let support = URL(string: "https://verg.app/support/")!
    static let download = URL(string: "https://verg.app/download/")!

    /// The listing, for the Rate and Share rows.
    static let appStore = URL(string: "https://apps.apple.com/app/id6758077555")!

    /// Deep-links straight to the review sheet rather than the listing.
    static let writeReview = URL(
        string: "https://apps.apple.com/app/id6758077555?action=write-review"
    )!
}
