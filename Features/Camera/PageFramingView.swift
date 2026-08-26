import SwiftUI
import UIKit

/// Position the photo inside the page frame before saving it.
///
/// Two problems, one control. A captured page is 3:4 already, so it needs
/// nothing — but a photo brought in from the library is whatever shape it
/// was, and the preview used to show it whole with `.fit` while the journal
/// showed a centre crop, so what you approved was not what you got. And a
/// page photographed slightly off-centre had no way to be corrected at all.
///
/// The frame is what will be kept. Everything outside it dims. Pinch to
/// scale, drag to move, and the result is reported as a rect normalised
/// against the image so the photo itself is never cut — see
/// `Session.cropRect`.
struct PageFramingView: UIViewRepresentable {
    let image: UIImage
    /// Normalised 0...1 against the image, reported as it changes.
    let onChange: (CGRect) -> Void

    func makeUIView(context: Context) -> FramingScrollView {
        let view = FramingScrollView()
        view.configure(with: image, onChange: onChange)
        return view
    }

    func updateUIView(_ view: FramingScrollView, context: Context) {
        view.configure(with: image, onChange: onChange)
    }
}

/// A scroll view doing the work a crop control needs: the page frame is its
/// bounds, so "what is visible" is exactly "what is kept", and zoom and pan
/// come from UIKit rather than from hand-rolled gestures fighting each
/// other.
final class FramingScrollView: UIView, UIScrollViewDelegate {

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private var onChange: ((CGRect) -> Void)?
    private var configuredFor: UIImage?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear
        imageView.contentMode = .scaleAspectFill
        scrollView.addSubview(imageView)
        addSubview(scrollView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    func configure(with image: UIImage, onChange: @escaping (CGRect) -> Void) {
        self.onChange = onChange
        guard configuredFor !== image else { return }
        configuredFor = image
        imageView.image = image
        setNeedsLayout()
        layoutIfNeeded()
        reset()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        if scrollView.zoomScale == scrollView.minimumZoomScale { reset() }
    }

    /// Start filling the frame — never letterboxed, because a page with bars
    /// down its sides is not a page.
    private func reset() {
        guard let image = imageView.image, bounds.width > 0, bounds.height > 0 else { return }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return }

        // Lay the image out at a scale that covers the frame, then let zoom
        // work from there. Minimum zoom is 1 so it can never be pulled
        // smaller than the frame it has to fill.
        let cover = max(bounds.width / size.width, bounds.height / size.height)
        let laid = CGSize(width: size.width * cover, height: size.height * cover)
        imageView.frame = CGRect(origin: .zero, size: laid)
        scrollView.contentSize = laid
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.zoomScale = 1
        // Centre on the middle of the photo, which is where the old
        // automatic crop looked too.
        scrollView.contentOffset = CGPoint(
            x: (laid.width - bounds.width) / 2,
            y: (laid.height - bounds.height) / 2
        )
        report()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    func scrollViewDidScroll(_ scrollView: UIScrollView) { report() }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { report() }

    /// What the frame currently shows, as a fraction of the whole image.
    private func report() {
        let content = scrollView.contentSize
        guard content.width > 0, content.height > 0, bounds.width > 0 else { return }
        let visible = CGRect(
            x: scrollView.contentOffset.x / content.width,
            y: scrollView.contentOffset.y / content.height,
            width: bounds.width / content.width,
            height: bounds.height / content.height
        )
        onChange?(visible)
    }
}
