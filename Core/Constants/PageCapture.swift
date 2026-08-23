import UIKit

/// The one shape a saved page is allowed to be.
///
/// The camera runs at the `.photo` preset, which is 4:3 — portrait, that's a
/// 3:4 page. Library photos arrive as whatever the user happened to shoot or
/// screenshot: 16:9, square, panoramic. Saving those unchanged meant the
/// journal held pages of several different shapes, so the grid and the
/// fullscreen viewer framed them inconsistently. Everything that becomes a
/// page goes through `normalized(_:)` first, camera captures included, so
/// there is exactly one code path deciding the format.
enum PageCapture {

    /// Width ÷ height. Portrait 3:4, matching the camera's `.photo` preset.
    static let aspectRatio: CGFloat = 3.0 / 4.0

    /// Crop `image` to the page format, centred.
    ///
    /// Centre-crop rather than letterbox: bars around a page would read as
    /// part of the photo. A source already at the right shape is returned
    /// untouched, so camera captures pay nothing to pass through here.
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
            // Too tall — take a full-width slice from the middle.
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
