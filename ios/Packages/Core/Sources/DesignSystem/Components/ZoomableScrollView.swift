import CoreGraphics
import SwiftUI

#if os(iOS)
  import UIKit
#endif

public struct ZoomTransform: Equatable, Sendable {
  private static let halfDivisor: CGFloat = 2

  public var scale: CGFloat
  public var contentOffset: CGPoint
  public var imageFrameInViewport: CGRect

  public static let identity = ZoomTransform(
    scale: 1,
    contentOffset: .zero,
    imageFrameInViewport: .zero
  )

  public init(scale: CGFloat, contentOffset: CGPoint, imageFrameInViewport: CGRect) {
    self.scale = scale
    self.contentOffset = contentOffset
    self.imageFrameInViewport = imageFrameInViewport
  }

  public static func aspectFitRect(aspectRatio: CGFloat, in containerSize: CGSize) -> CGRect {
    guard containerSize.width > 0, containerSize.height > 0, aspectRatio > 0 else {
      return .zero
    }
    let containerAspect = containerSize.width / containerSize.height
    let fittedSize: CGSize
    if containerAspect > aspectRatio {
      fittedSize = CGSize(width: containerSize.height * aspectRatio, height: containerSize.height)
    } else {
      fittedSize = CGSize(width: containerSize.width, height: containerSize.width / aspectRatio)
    }
    let origin = CGPoint(
      x: (containerSize.width - fittedSize.width) / halfDivisor,
      y: (containerSize.height - fittedSize.height) / halfDivisor
    )
    return CGRect(origin: origin, size: fittedSize)
  }
}

public struct ZoomableScrollView: View {
  private let image: CGImage
  @Binding private var transform: ZoomTransform
  private let onSingleTap: () -> Void

  public init(
    image: CGImage,
    transform: Binding<ZoomTransform>,
    onSingleTap: @escaping () -> Void = {}
  ) {
    self.image = image
    self._transform = transform
    self.onSingleTap = onSingleTap
  }

  public var body: some View {
    #if os(iOS)
      ZoomableScrollRepresentable(
        image: image,
        transform: $transform,
        onSingleTap: onSingleTap
      )
    #else
      GeometryReader { geometry in
        let aspectRatio = CGFloat(image.width) / max(CGFloat(image.height), 1)
        let rect = ZoomTransform.aspectFitRect(aspectRatio: aspectRatio, in: geometry.size)
        Image(decorative: image, scale: 1)
          .resizable()
          .scaledToFit()
          .frame(width: geometry.size.width, height: geometry.size.height)
          .contentShape(Rectangle())
          .onTapGesture(perform: onSingleTap)
          .onAppear {
            transform = ZoomTransform(scale: 1, contentOffset: .zero, imageFrameInViewport: rect)
          }
          .onChange(of: geometry.size) { _, newSize in
            let updatedRect = ZoomTransform.aspectFitRect(aspectRatio: aspectRatio, in: newSize)
            transform = ZoomTransform(
              scale: 1,
              contentOffset: .zero,
              imageFrameInViewport: updatedRect
            )
          }
      }
    #endif
  }
}

#if os(iOS)
  struct ZoomableScrollRepresentable: UIViewRepresentable {
    static let minZoomScale: CGFloat = 1
    static let maxZoomScale: CGFloat = 5
    static let doubleTapZoomScale: CGFloat = 2.5
    static let resetZoomTolerance: CGFloat = 0.01
    private static let doubleTapCount = 2

    let image: CGImage
    @Binding var transform: ZoomTransform
    let onSingleTap: () -> Void

    func makeCoordinator() -> ZoomableScrollCoordinator {
      ZoomableScrollCoordinator(parent: self)
    }

    func makeUIView(context: Context) -> LayoutNotifyingScrollView {
      let scrollView = LayoutNotifyingScrollView()
      scrollView.delegate = context.coordinator
      scrollView.minimumZoomScale = Self.minZoomScale
      scrollView.maximumZoomScale = Self.maxZoomScale
      scrollView.bouncesZoom = true
      scrollView.showsHorizontalScrollIndicator = false
      scrollView.showsVerticalScrollIndicator = false
      scrollView.contentInsetAdjustmentBehavior = .never
      scrollView.backgroundColor = .clear

      let hostController = UIHostingController(rootView: makeImageView(for: image))
      hostController.view.backgroundColor = .clear
      hostController.safeAreaRegions = []
      scrollView.addSubview(hostController.view)

      let doubleTap = UITapGestureRecognizer(
        target: context.coordinator,
        action: #selector(ZoomableScrollCoordinator.handleDoubleTap(_:))
      )
      doubleTap.numberOfTapsRequired = Self.doubleTapCount
      scrollView.addGestureRecognizer(doubleTap)

      let singleTap = UITapGestureRecognizer(
        target: context.coordinator,
        action: #selector(ZoomableScrollCoordinator.handleSingleTap)
      )
      singleTap.require(toFail: doubleTap)
      scrollView.addGestureRecognizer(singleTap)

      context.coordinator.scrollView = scrollView
      context.coordinator.hostController = hostController
      scrollView.onLayout = { [weak coordinator = context.coordinator] in
        coordinator?.syncLayoutIfNeeded()
      }
      return scrollView
    }

    func updateUIView(_ scrollView: LayoutNotifyingScrollView, context: Context) {
      context.coordinator.parent = self
      context.coordinator.updateImage(image)
    }

    func makeImageView(for cgImage: CGImage) -> AnyView {
      AnyView(
        Image(decorative: cgImage, scale: 1)
          .resizable()
          .scaledToFit()
      )
    }
  }
#endif
