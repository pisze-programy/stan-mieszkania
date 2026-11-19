#if os(iOS)
  import CoreGraphics
  import SwiftUI
  import UIKit

  @MainActor
  final class ZoomableScrollCoordinator: NSObject, UIScrollViewDelegate {
    private static let aspectRatioEpsilon: CGFloat = 0.001
    private static let halfDivisor: CGFloat = 2

    var parent: ZoomableScrollRepresentable
    weak var scrollView: LayoutNotifyingScrollView?
    var hostController: UIHostingController<AnyView>?
    private var lastViewportSize: CGSize = .zero
    private var lastAspectRatio: CGFloat = 0
    private var lastReportedTransform: ZoomTransform = .identity

    init(parent: ZoomableScrollRepresentable) {
      self.parent = parent
    }

    func updateImage(_ image: CGImage) {
      hostController?.rootView = parent.makeImageView(for: image)
      syncLayoutIfNeeded()
    }

    func syncLayoutIfNeeded() {
      guard let scrollView, let hostView = hostController?.view else {
        return
      }
      let viewport = scrollView.bounds.size
      guard viewport.width > 0, viewport.height > 0 else {
        return
      }
      let aspectRatio = CGFloat(parent.image.width) / max(CGFloat(parent.image.height), 1)
      let aspectChanged = abs(aspectRatio - lastAspectRatio) > Self.aspectRatioEpsilon
      if viewport != lastViewportSize || aspectChanged {
        lastViewportSize = viewport
        lastAspectRatio = aspectRatio
        let baseRect = ZoomTransform.aspectFitRect(aspectRatio: aspectRatio, in: viewport)
        scrollView.zoomScale = ZoomableScrollRepresentable.minZoomScale
        hostView.transform = .identity
        hostView.frame = CGRect(origin: .zero, size: baseRect.size)
        scrollView.contentSize = baseRect.size
        updateContentInsets(for: scrollView, hostView: hostView)
        scrollView.contentOffset = CGPoint(
          x: -scrollView.contentInset.left,
          y: -scrollView.contentInset.top
        )
      }
      publishTransform(from: scrollView, hostView: hostView, async: true)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
      hostController?.view
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
      guard let hostView = hostController?.view else {
        return
      }
      updateContentInsets(for: scrollView, hostView: hostView)
      publishTransform(from: scrollView, hostView: hostView, async: false)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
      guard let hostView = hostController?.view else {
        return
      }
      publishTransform(from: scrollView, hostView: hostView, async: false)
    }

    @objc func handleSingleTap() {
      parent.onSingleTap()
    }

    @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
      guard let scrollView, let hostView = hostController?.view else {
        return
      }
      let resetThreshold =
        ZoomableScrollRepresentable.minZoomScale
        + ZoomableScrollRepresentable.resetZoomTolerance
      if scrollView.zoomScale > resetThreshold {
        scrollView.setZoomScale(ZoomableScrollRepresentable.minZoomScale, animated: true)
        return
      }
      let tapPoint = recognizer.location(in: hostView)
      let targetScale = ZoomableScrollRepresentable.doubleTapZoomScale
      let zoomWidth = scrollView.bounds.width / targetScale
      let zoomHeight = scrollView.bounds.height / targetScale
      let zoomRect = CGRect(
        x: tapPoint.x - zoomWidth / Self.halfDivisor,
        y: tapPoint.y - zoomHeight / Self.halfDivisor,
        width: zoomWidth,
        height: zoomHeight
      )
      scrollView.zoom(to: zoomRect, animated: true)
    }

    private func updateContentInsets(for scrollView: UIScrollView, hostView: UIView) {
      let horizontal = max((scrollView.bounds.width - hostView.frame.width) / Self.halfDivisor, 0)
      let vertical = max((scrollView.bounds.height - hostView.frame.height) / Self.halfDivisor, 0)
      scrollView.contentInset = UIEdgeInsets(
        top: vertical,
        left: horizontal,
        bottom: vertical,
        right: horizontal
      )
    }

    private func publishTransform(
      from scrollView: UIScrollView,
      hostView: UIView,
      async: Bool
    ) {
      let frameInViewport = CGRect(
        x: hostView.frame.minX - scrollView.contentOffset.x,
        y: hostView.frame.minY - scrollView.contentOffset.y,
        width: hostView.frame.width,
        height: hostView.frame.height
      )
      let updated = ZoomTransform(
        scale: scrollView.zoomScale,
        contentOffset: scrollView.contentOffset,
        imageFrameInViewport: frameInViewport
      )
      guard updated != lastReportedTransform else {
        return
      }
      lastReportedTransform = updated
      if async {
        Task { @MainActor in
          parent.transform = updated
        }
      } else {
        parent.transform = updated
      }
    }
  }

  final class LayoutNotifyingScrollView: UIScrollView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
      super.layoutSubviews()
      onLayout?()
    }
  }
#endif
