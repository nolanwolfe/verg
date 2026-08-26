import UIKit

/// The one shape a page is *shown* in — and, deliberately, not the shape it
/// is stored in.
///
/// Photos are saved whole. Nothing is cropped on the way to disk; the frame
/// is applied by `framed(_:)` at display time, every time. That costs a
/// centre-crop per render and buys the thing that matters: the format stays
/// a decision rather than a commitment. Change `aspectRatio` and every page
/// ever saved re-frames itself, including the parts a previous format threw
/// away.
///
/// It did not work this way until 2.2. The crop ran at save time, so each
/// format change quietly destroyed pixels and could never be walked back —
/// pages saved under a landscape format had already lost their top and
/// bottom by the time anyone decided portrait was right. That is the bug
/// this arrangement exists to prevent, and it is why the viewfinder mask is
/// a *guide* rather than a crop: what falls outside it is still captured.
enum PageCapture {

    /// Width ÷ height. Portrait 3:4.
    ///
    /// The shape of a single page. A composition or Letter page is 0.77, A5
    /// is 0.70, and a Moleskine is 0.62 — 3:4 (0.75) sits in the middle of
    /// the range, so a page fills the frame instead of floating in it.
    ///
    /// This replaced a landscape 3:2, which had been chosen for an open
    /// two-page spread. The premise was wrong: a session produces one page,
    /// which is what the data model has always called it. Landscape cost
    /// three things at once — the phone is portrait-locked, so framing a
    /// portrait page through a landscape band meant backing away until the
    /// writing was small; reviewing a 3:2 image on a portrait screen filled
    /// about a third of it, so reading your own handwriting needed a zoom;
    /// and a centre-crop to 3:2 discarded ~45% of a portrait library photo.
    ///
    /// The grid is the one argument against going tall — square tiles make a
    /// calmer wall. It loses to capture and review, which happen daily.
    static let aspectRatio: CGFloat = 3.0 / 4.0

    /// Centre-crop `image` to the page format, for display.
    ///
    /// Centre-crop rather than letterbox: bars around a page would read as
    /// part of the photo. A source already at the right shape is returned
    /// untouched.
    ///
    /// The crop is applied in *pixel* space against the oriented image, and
    /// the result is redrawn upright — cropping a `CGImage` directly ignores
    /// `imageOrientation`, which is how a sideways-EXIF photo ends up cropped
    /// along the wrong axis.
    /// Frame `image` using an explicit rect the user chose, normalised
    /// 0...1 against the image. Falls back to the centre crop when there
    /// isn't one — every page saved before framing existed, and every photo
    /// the user did not adjust.
    ///
    /// The rect is honoured for position and scale but the *aspect* always
    /// comes from `aspectRatio`, so changing the page format re-frames an
    /// adjusted photo around the part the user chose rather than stranding
    /// it at the old shape.
    static func framed(_ image: UIImage, crop: CGRect?) -> UIImage {
        guard let crop, crop.width > 0, crop.height > 0 else {
            return framed(image)
        }
        let w = image.size.width, h = image.size.height
        guard w > 0, h > 0 else { return image }

        // Keep the chosen centre; take the largest rect at the page aspect
        // that fits inside what they framed.
        let centre = CGPoint(x: crop.midX * w, y: crop.midY * h)
        var cw = crop.width * w
        var ch = crop.height * h
        if cw / ch > aspectRatio {
            cw = ch * aspectRatio
        } else {
            ch = cw / aspectRatio
        }
        // Nudge back inside the image rather than sampling past its edge.
        var x = centre.x - cw / 2
        var y = centre.y - ch / 2
        x = min(max(0, x), max(0, w - cw))
        y = min(max(0, y), max(0, h - ch))

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: cw, height: ch), format: format)
            .image { _ in image.draw(at: CGPoint(x: -x, y: -y)) }
    }

    static func framed(_ image: UIImage) -> UIImage {
        let width = image.size.width
        let height = image.size.height
        guard width > 0, height > 0 else { return image }

        let currentRatio = width / height
        // Within half a percent of the target is already the right shape.
        guard abs(currentRatio - aspectRatio) > 0.005 else { return image }

        let targetSize: CGSize
        if currentRatio > aspectRatio {
            // Too wide — take a full-height slice from the middle.
            targetSize = CGSize(width: height * aspectRatio, height: height)
        } else {
            // Too tall — take a full-width slice from the middle. This is
            // now the common case: a phone held upright over a notebook
            // produces a portrait frame, and the page lives in the band
            // across its middle.
            targetSize = CGSize(width: width, height: width / aspectRatio)
        }

        let origin = CGPoint(
            x: (width - targetSize.width) / 2,
            y: (height - targetSize.height) / 2
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(at: CGPoint(x: -origin.x, y: -origin.y))
        }
    }
}
