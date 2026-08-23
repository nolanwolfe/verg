import SwiftUI
import UIKit

/// Pinch-to-zoom, pan, and swipe-down-to-dismiss for the fullscreen page
/// viewer. Built on UIScrollView rather than SwiftUI's native gestures: a
/// SwiftUI DragGesture on top of TabView's own paging gesture fights it for
/// the same touch, so zoom/pan is delegated to UIKit exactly like Photos.app
/// does, and only the dismiss pan is a separate recognizer layered on top.
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    var onDismiss: () -> Void
    var onDragProgressChanged: (CGFloat) -> Void = { _ in }

    private let maxZoomScale: CGFloat = 4
    private let dismissDistance: CGFloat = 120
    private let dismissVelocity: CGFloat = 800

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = maxZoomScale
        scrollView.minimumZoomScale = 1
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        context.coordinator.imageView = imageView
        scrollView.addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTap)

        let dismissPan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDismissPan(_:))
        )
        dismissPan.delegate = context.coordinator
        scrollView.addGestureRecognizer(dismissPan)

        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.imageView?.image = image
        context.coordinator.layout()
    }

    static func dismantleUIView(_ scrollView: UIScrollView, coordinator: Coordinator) {
        scrollView.gestureRecognizers?.forEach { scrollView.removeGestureRecognizer($0) }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var parent: ZoomableImageView
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?

        /// The scrollView bounds size we last laid out the 1x "fit" geometry
        /// for. SwiftUI calls `updateUIView` — and therefore `layout()` — on
        /// every re-render, including mid-swipe; re-deriving fit geometry
        /// from the current (already-zoomed) bounds on every one of those
        /// calls desyncs `scrollView.zoomScale` from the actual bounds, and
        /// the next gesture reapplies the stale scale on top of the reset
        /// geometry, compounding into a runaway zoom. Only reset when the
        /// viewport itself changed size (first layout, rotation).
        private var lastLaidOutBoundsSize: CGSize = .zero

        init(_ parent: ZoomableImageView) {
            self.parent = parent
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage()
        }

        func layout() {
            guard let scrollView, let imageView, let image = imageView.image else { return }
            let boundsSize = scrollView.bounds.size
            guard boundsSize.width > 0, boundsSize.height > 0, image.size.width > 0 else { return }

            guard boundsSize != lastLaidOutBoundsSize else {
                centerImage()
                return
            }
            lastLaidOutBoundsSize = boundsSize

            let scale = min(boundsSize.width / image.size.width, boundsSize.height / image.size.height)
            let fitSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            scrollView.zoomScale = 1
            imageView.bounds = CGRect(origin: .zero, size: fitSize)
            scrollView.contentSize = fitSize
            centerImage()
        }

        private func centerImage() {
            guard let scrollView, let imageView else { return }
            let boundsSize = scrollView.bounds.size
            let contentSize = scrollView.contentSize
            let horizontalInset = max(0, (boundsSize.width - contentSize.width) / 2)
            let verticalInset = max(0, (boundsSize.height - contentSize.height) / 2)
            imageView.center = CGPoint(
                x: contentSize.width / 2 + horizontalInset,
                y: contentSize.height / 2 + verticalInset
            )
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let fillScale = scrollView.maximumZoomScale * 0.6
                let point = gesture.location(in: imageView)
                let size = CGSize(
                    width: scrollView.bounds.width / fillScale,
                    height: scrollView.bounds.height / fillScale
                )
                let rect = CGRect(
                    x: point.x - size.width / 2,
                    y: point.y - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                scrollView.zoom(to: rect, animated: true)
            }
        }

        /// Only engages when unzoomed — while zoomed, UIScrollView's own pan
        /// handles panning the content and this recognizer is a no-op, so the
        /// two never compete for the same touch.
        @objc func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
            guard let scrollView, let imageView else { return }
            guard scrollView.zoomScale <= scrollView.minimumZoomScale + 0.01 else { return }

            let translation = gesture.translation(in: scrollView)
            switch gesture.state {
            case .changed:
                guard translation.y > 0 else {
                    imageView.transform = .identity
                    parent.onDragProgressChanged(0)
                    return
                }
                let dragged = rubberBanded(translation.y, dimension: scrollView.bounds.height)
                imageView.transform = CGAffineTransform(translationX: translation.x * 0.25, y: dragged)
                parent.onDragProgressChanged(min(1, dragged / parent.dismissDistance))
            case .ended:
                let velocity = gesture.velocity(in: scrollView)
                if translation.y > parent.dismissDistance || velocity.y > parent.dismissVelocity {
                    parent.onDismiss()
                } else {
                    resetDrag(imageView)
                }
            case .cancelled, .failed:
                // A cancelled gesture is not a decision. This used to share a
                // branch with `.ended`, so a drag the system took away — the
                // pager claiming the touch, a phone call — could dismiss the
                // viewer on the user's behalf.
                resetDrag(imageView)
            default:
                break
            }
        }

        private func resetDrag(_ imageView: UIImageView) {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                imageView.transform = .identity
            }
            parent.onDragProgressChanged(0)
        }

        /// Standard iOS rubber-band curve — diminishing returns past the
        /// linear drag so the gesture never feels like it runs out of room.
        private func rubberBanded(_ delta: CGFloat, dimension: CGFloat) -> CGFloat {
            guard dimension > 0 else { return delta }
            let c: CGFloat = 0.55
            return (1 - (1 / ((delta * c / dimension) + 1))) * dimension
        }

        /// The dismiss pan may only claim a *downward* drag. Without this it
        /// began on every touch, including the horizontal ones belonging to
        /// the pager: swiping between pages ran `handleDismissPan` too, so any
        /// downward drift in the swipe slid the photo inside its own page and
        /// faded the chrome out — the flicker/jump seen when moving from one
        /// entry to the next. Direction is judged from velocity at the moment
        /// the gesture would begin, which is how UIKit itself disambiguates.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let scrollView else { return true }
            guard scrollView.zoomScale <= scrollView.minimumZoomScale + 0.01 else { return false }
            let velocity = pan.velocity(in: scrollView)
            return velocity.y > abs(velocity.x)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Only share touches with this scroll view's own recognizers (its
            // pan and pinch). Returning `true` unconditionally also opted in
            // the pager's gesture, letting both drive the same drag.
            otherGestureRecognizer.view === scrollView
        }
    }
}
