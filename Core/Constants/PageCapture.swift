import UIKit

/// The one shape a saved page is allowed to be.
///
/// Library photos arrive as whatever the user happened to shoot or
/// screenshot: 16:9, square, panoramic, portrait. Saving those unchanged
/// meant the journal held pages of several different shapes, so the grid and
/// the fullscreen viewer framed them inconsistently. Everything that becomes
/// a page goes through `normalized(_:)` first, camera captures included, so
/// there is exactly one code path deciding the format.
///
/// The camera runs at the `.photo` preset — 4:3, which held upright is a 3:4
/// portrait frame — so a capture is now cropped to the landscape page shape
/// like everything else.
enum PageCapture {

    /// Width ÷ height. Landscape 3:2.
    ///
    /// A notebook open on a desk is wider than it is tall, and a page shot
    /// from above fills a landscape frame far better than the portrait one
    /// this used to be — the old 3:4 threw away the sides of a spread and
    /// left dead desk above and below it.
    ///
    /// 3:2 rather than 16:9: 16:9 is a cinema crop and would slice the top
    /// and bottom lines off a page. 3:2 is the 35mm frame — landscape enough
    /// to hold a spread, shallow enough to keep the whole page.
    static let aspectRatio: CGFloat = 3.0 / 2.0

    /// Crop `image` to the page format, centred.
    ///
    /// Centre-crop rather than letterbox: bars around a page would read as
    /// part of the photo. A source already at the right shape is returned
    /// untouched — though since the page format went landscape that no
    /// longer includes camera captures, which arrive portrait and are cropped
    /// like everything else. The viewfinder is masked to the same shape, so
    /// what gets cropped away was never shown as part of the shot.
    ///
    /// The crop is applied in *pixel* space against the oriented image, and
    /// the result is redrawn upright — cropping a `CGImage` directly ignores
    /// `imageOrientation`, which is how a sideways-EXIF photo ends up cropped
    /// along the wrong axis.
    static func normalized(_ image: UIImage) -> UIImage {
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
