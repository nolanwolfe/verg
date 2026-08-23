import XCTest
import UIKit
@testable import Verg

/// The page-format lock. Every saved page — captured or picked from the
/// library — is meant to come out the same shape, so this covers the shapes
/// a library photo actually arrives in.
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

    func testPortraitThreeByFourIsLeftAlone() {
        // What the camera itself produces — must pass through untouched, not
        // get re-rendered on every capture.
        let source = image(1536, 2048)
        let result = PageCapture.normalized(source)
        XCTAssertEqual(result.size, source.size)
    }

    func testLandscapePhotoIsCroppedToPageShape() {
        let result = PageCapture.normalized(image(4032, 3024))
        assertIsPageShaped(result, "A landscape photo should come out page-shaped")
        // Full height retained; width is the slice taken from the middle.
        XCTAssertEqual(result.size.height, 3024, accuracy: 1)
        XCTAssertEqual(result.size.width, 3024 * PageCapture.aspectRatio, accuracy: 1)
    }

    func testTallScreenshotIsCroppedToPageShape() {
        // A modern iPhone screenshot — the case that most visibly broke the
        // journal's framing before the lock existed.
        let result = PageCapture.normalized(image(1179, 2556))
        assertIsPageShaped(result, "A tall screenshot should come out page-shaped")
        XCTAssertEqual(result.size.width, 1179, accuracy: 1)
        XCTAssertEqual(result.size.height, 1179 / PageCapture.aspectRatio, accuracy: 1)
    }

    func testSquareIsCroppedToPageShape() {
        let result = PageCapture.normalized(image(2000, 2000))
        assertIsPageShaped(result, "A square photo should come out page-shaped")
        // A square is *wider* than 3:4, so height is kept and width narrows.
        XCTAssertEqual(result.size.height, 2000, accuracy: 1)
        XCTAssertEqual(result.size.width, 1500, accuracy: 1)
    }

    func testPanoramaIsCroppedToPageShape() {
        let result = PageCapture.normalized(image(8000, 1500))
        assertIsPageShaped(result, "Even a panorama should come out page-shaped")
    }

    func testCropNeverEnlargesEitherDimension() {
        // The crop takes a slice; it must never invent pixels by scaling up.
        for (w, h) in [(4032.0, 3024.0), (1179.0, 2556.0), (2000.0, 2000.0)] {
            let result = PageCapture.normalized(image(CGFloat(w), CGFloat(h)))
            XCTAssertLessThanOrEqual(result.size.width, CGFloat(w) + 1)
            XCTAssertLessThanOrEqual(result.size.height, CGFloat(h) + 1)
        }
    }

    func testEveryShapeAgreesOnOneFormat() {
        // The actual promise: whatever went in, the journal holds one shape.
        let ratios = [(4032.0, 3024.0), (1179.0, 2556.0), (2000.0, 2000.0), (1536.0, 2048.0)]
            .map { ratio(PageCapture.normalized(image(CGFloat($0.0), CGFloat($0.1)))) }
        for r in ratios {
            XCTAssertEqual(r, PageCapture.aspectRatio, accuracy: 0.01)
        }
    }

    func testDegenerateSizeIsReturnedUnchanged() {
        let empty = UIImage()
        XCTAssertEqual(PageCapture.normalized(empty).size, empty.size)
    }
}
