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

    func testAlreadyLandscapeThreeByTwoIsLeftAlone() {
        // The page format itself — must pass through untouched rather than
        // being re-rendered for nothing.
        let source = image(3000, 2000)
        let result = PageCapture.normalized(source)
        XCTAssertEqual(result.size, source.size)
    }

    func testCameraCaptureIsCroppedToLandscape() {
        // A phone held upright over a notebook gives a 3:4 portrait frame.
        // The page lives in the band across its middle.
        let result = PageCapture.normalized(image(1536, 2048))
        assertIsPageShaped(result, "A portrait capture should come out page-shaped")
        XCTAssertEqual(result.size.width, 1536, accuracy: 1)
        XCTAssertEqual(result.size.height, 1536 / PageCapture.aspectRatio, accuracy: 1)
    }

    func testFourByThreeLandscapeIsCroppedToPageShape() {
        // 4:3 is wider than tall but still squarer than 3:2, so height goes.
        let result = PageCapture.normalized(image(4032, 3024))
        assertIsPageShaped(result, "A 4:3 photo should come out page-shaped")
        XCTAssertEqual(result.size.width, 4032, accuracy: 1)
        XCTAssertEqual(result.size.height, 4032 / PageCapture.aspectRatio, accuracy: 1)
    }

    func testSixteenByNineIsCroppedToPageShape() {
        // Wider than the page format — this one loses width, not height.
        let result = PageCapture.normalized(image(1920, 1080))
        assertIsPageShaped(result, "A 16:9 photo should come out page-shaped")
        XCTAssertEqual(result.size.height, 1080, accuracy: 1)
        XCTAssertEqual(result.size.width, 1080 * PageCapture.aspectRatio, accuracy: 1)
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
        // A square is *taller* than 3:2, so width is kept and height narrows.
        XCTAssertEqual(result.size.width, 2000, accuracy: 1)
        XCTAssertEqual(result.size.height, 2000 / PageCapture.aspectRatio, accuracy: 1)
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
        let ratios = [(4032.0, 3024.0), (1179.0, 2556.0), (2000.0, 2000.0), (1920.0, 1080.0)]
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
