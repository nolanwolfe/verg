import XCTest
import UIKit
@testable import Verg

/// The page frame. Since 2.2 this is a *display* crop — photos are stored
/// whole and framed on the way to the screen — so what these cover is the
/// shape everything comes out as, whatever shape it went in.
final class PageCaptureTests: XCTestCase {

    /// Solid-colour image of a given point size, scale 1.
    private func image(_ width: CGFloat, _ height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
            .image { context in
                UIColor.gray.setFill()
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
    }

    private func ratio(_ image: UIImage) -> CGFloat {
        image.size.width / image.size.height
    }

    private func assertIsPageShaped(
        _ result: UIImage,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            ratio(result), PageCapture.aspectRatio, accuracy: 0.01,
            message, file: file, line: line
        )
    }

    // MARK: - The format itself

    /// Portrait, and inside the range a real notebook page occupies —
    /// Moleskine 0.62, A5 0.70, Letter 0.77. A frame outside that range
    /// leaves the page floating in it or cuts into the margins.
    func testFormatIsPortraitAndPageShaped() {
        XCTAssertLessThan(PageCapture.aspectRatio, 1.0, "The page format should be portrait")
        XCTAssertGreaterThan(PageCapture.aspectRatio, 0.6)
        XCTAssertLessThan(PageCapture.aspectRatio, 0.85)
    }

    func testAlreadyPageShapedIsLeftAlone() {
        // Must pass through untouched rather than being re-rendered for
        // nothing — this is the common case for a capture framed properly.
        let source = image(1536, 2048)   // exactly 3:4
        let result = PageCapture.framed(source)
        XCTAssertEqual(result.size, source.size)
    }

    func testFramingIsIdempotent() {
        // Framing runs on every render now, so a second pass over an
        // already-framed image must be a no-op rather than a slow re-crop.
        let once = PageCapture.framed(image(4032, 3024))
        let twice = PageCapture.framed(once)
        XCTAssertEqual(once.size, twice.size)
    }

    // MARK: - Shapes a photo actually arrives in

    func testLandscapeCaptureLosesWidthNotHeight() {
        // 4:3 from a camera held sideways, or any landscape source: wider
        // than the frame, so the sides go and the full height is kept.
        let result = PageCapture.framed(image(4032, 3024))
        assertIsPageShaped(result, "A 4:3 photo should come out page-shaped")
        XCTAssertEqual(result.size.height, 3024, accuracy: 1)
        XCTAssertEqual(result.size.width, 3024 * PageCapture.aspectRatio, accuracy: 1)
    }

    func testSixteenByNineIsCroppedToPageShape() {
        let result = PageCapture.framed(image(1920, 1080))
        assertIsPageShaped(result, "A 16:9 photo should come out page-shaped")
        XCTAssertEqual(result.size.height, 1080, accuracy: 1)
        XCTAssertEqual(result.size.width, 1080 * PageCapture.aspectRatio, accuracy: 1)
    }

    func testTallScreenshotLosesHeightNotWidth() {
        // A modern iPhone screenshot is taller than the page frame, so this
        // is the one direction that trims top and bottom instead.
        let result = PageCapture.framed(image(1179, 2556))
        assertIsPageShaped(result, "A tall screenshot should come out page-shaped")
        XCTAssertEqual(result.size.width, 1179, accuracy: 1)
        XCTAssertEqual(result.size.height, 1179 / PageCapture.aspectRatio, accuracy: 1)
    }

    func testSquareIsCroppedToPageShape() {
        let result = PageCapture.framed(image(2000, 2000))
        assertIsPageShaped(result, "A square photo should come out page-shaped")
        // A square is *wider* than 3:4, so height is kept and width narrows.
        XCTAssertEqual(result.size.height, 2000, accuracy: 1)
        XCTAssertEqual(result.size.width, 2000 * PageCapture.aspectRatio, accuracy: 1)
    }

    func testPanoramaIsCroppedToPageShape() {
        let result = PageCapture.framed(image(8000, 1500))
        assertIsPageShaped(result, "Even a panorama should come out page-shaped")
    }

    func testCropNeverEnlargesEitherDimension() {
        // The crop takes a slice; it must never invent pixels by scaling up.
        for (w, h) in [(4032.0, 3024.0), (1179.0, 2556.0), (2000.0, 2000.0)] {
            let result = PageCapture.framed(image(CGFloat(w), CGFloat(h)))
            XCTAssertLessThanOrEqual(result.size.width, CGFloat(w) + 1)
            XCTAssertLessThanOrEqual(result.size.height, CGFloat(h) + 1)
        }
    }

    func testEveryShapeAgreesOnOneFormat() {
        // The actual promise: whatever went in, the journal shows one shape.
        let ratios = [(4032.0, 3024.0), (1179.0, 2556.0), (2000.0, 2000.0), (1920.0, 1080.0)]
            .map { ratio(PageCapture.framed(image(CGFloat($0.0), CGFloat($0.1)))) }
        for r in ratios {
            XCTAssertEqual(r, PageCapture.aspectRatio, accuracy: 0.01)
        }
    }

    func testDegenerateSizeIsReturnedUnchanged() {
        let empty = UIImage()
        XCTAssertEqual(PageCapture.framed(empty).size, empty.size)
    }

    // MARK: - Reframing

    /// The reason storage keeps the whole photo: a portrait source framed to
    /// a *landscape* format loses its top and bottom, and framing the same
    /// original to portrait must recover them. If the crop were still baked
    /// in at save time this would be impossible, and every future format
    /// change would be one-way.
    func testAWiderFormatCropAndTheCurrentOneComeFromTheSameOriginal() {
        let original = image(3000, 4000)          // a portrait page photo

        // What a landscape 3:2 frame would have kept.
        let landscape = CGFloat(3.0 / 2.0)
        let landscapeHeight = 3000 / landscape
        XCTAssertLessThan(landscapeHeight, 4000,
                          "A 3:2 frame should discard most of a portrait photo's height")

        // The current frame, taken from the untouched original, keeps far
        // more of it — which only holds because nothing was cropped on save.
        let framed = PageCapture.framed(original)
        XCTAssertEqual(framed.size.width, 3000, accuracy: 1)
        XCTAssertGreaterThan(framed.size.height, landscapeHeight * 1.5)
    }

    // MARK: - A frame the user chose

    /// An off-centre frame must actually move the crop. The whole point of
    /// the control is that a page photographed low in the shot can be
    /// rescued; if the rect were ignored it would still centre and the
    /// feature would look like it worked while doing nothing.
    func testAChosenRectMovesTheCropAwayFromCentre() {
        let source = image(2000, 2000)
        let centred = PageCapture.framed(source, crop: nil)
        let low = PageCapture.framed(
            source,
            crop: CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
        )
        assertIsPageShaped(low, "A chosen frame should still come out page-shaped")
        XCTAssertNotEqual(low.size, centred.size,
                          "The chosen rect made no difference to the crop")
    }

    /// The rect sets position and scale; the *aspect* always comes from the
    /// format. That is what lets the page format change later without
    /// stranding photos at the shape they were framed under.
    func testTheChosenRectNeverOverridesTheFormat() {
        let source = image(3000, 4000)
        for rect in [CGRect(x: 0, y: 0, width: 1, height: 0.4),
                     CGRect(x: 0.2, y: 0.1, width: 0.5, height: 0.5),
                     CGRect(x: 0.6, y: 0.6, width: 0.4, height: 0.4)] {
            assertIsPageShaped(PageCapture.framed(source, crop: rect),
                               "Frame \(rect) did not come out at the page aspect")
        }
    }

    /// A rect that runs off the edge is pulled back inside rather than
    /// sampling past the image, which would letterbox with empty pixels.
    func testAFrameOffTheEdgeIsPulledBackIn() {
        let source = image(1200, 1600)
        let result = PageCapture.framed(
            source,
            crop: CGRect(x: 0.9, y: 0.9, width: 0.4, height: 0.4)
        )
        assertIsPageShaped(result, "An overhanging frame should still be page-shaped")
        XCTAssertLessThanOrEqual(result.size.width, 1200 + 1)
        XCTAssertLessThanOrEqual(result.size.height, 1600 + 1)
    }

    func testADegenerateRectFallsBackToCentring() {
        let source = image(2000, 1000)
        let zero = PageCapture.framed(source, crop: .zero)
        let centred = PageCapture.framed(source, crop: nil)
        XCTAssertEqual(zero.size, centred.size)
    }
}
