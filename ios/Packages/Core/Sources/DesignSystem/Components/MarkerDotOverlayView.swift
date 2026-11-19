import Domain
import SwiftUI

public struct MarkerOverlayItem: Identifiable, Sendable, Equatable, Hashable {
  public let id: String
  public let number: Int
  public let x: Double
  public let y: Double
  public let authorColorHex: String

  public init(
    id: String,
    number: Int,
    x: Double,
    y: Double,
    authorColorHex: String
  ) {
    self.id = id
    self.number = number
    self.x = x
    self.y = y
    self.authorColorHex = authorColorHex
  }

  public static func clampedNormalizedCoordinate(_ value: Double) -> Double {
    min(max(value, ContractConstants.markerCoordMin), ContractConstants.markerCoordMax)
  }

  public static func pointInContainer(_ item: MarkerOverlayItem, size: CGSize) -> CGPoint {
    let clampedX = clampedNormalizedCoordinate(item.x)
    let clampedY = clampedNormalizedCoordinate(item.y)
    return CGPoint(x: clampedX * size.width, y: clampedY * size.height)
  }

  public static func normalizedPoint(for location: CGPoint, in size: CGSize) -> (Double, Double) {
    guard size.width > 0, size.height > 0 else {
      return (ContractConstants.markerCoordMin, ContractConstants.markerCoordMin)
    }
    let normalizedX = clampedNormalizedCoordinate(Double(location.x / size.width))
    let normalizedY = clampedNormalizedCoordinate(Double(location.y / size.height))
    return (normalizedX, normalizedY)
  }
}

public struct MarkerDotOverlayView: View {
  private let markers: [MarkerOverlayItem]
  private let selectedMarkerNumber: Int?
  private let onSelectMarker: (Int) -> Void
  private let onDeselectAll: () -> Void
  private let onAddMarkerAtNormalizedPoint: ((Double, Double) -> Void)?

  public init(
    markers: [MarkerOverlayItem],
    selectedMarkerNumber: Int?,
    onSelectMarker: @escaping (Int) -> Void,
    onDeselectAll: @escaping () -> Void,
    onAddMarkerAtNormalizedPoint: ((Double, Double) -> Void)? = nil
  ) {
    self.markers = markers
    self.selectedMarkerNumber = selectedMarkerNumber
    self.onSelectMarker = onSelectMarker
    self.onDeselectAll = onDeselectAll
    self.onAddMarkerAtNormalizedPoint = onAddMarkerAtNormalizedPoint
  }

  public var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color.clear
          .contentShape(Rectangle())
          .gesture(
            SpatialTapGesture()
              .onEnded { value in
                if let onAddMarkerAtNormalizedPoint {
                  let (nx, ny) = MarkerOverlayItem.normalizedPoint(
                    for: value.location,
                    in: geometry.size
                  )
                  onAddMarkerAtNormalizedPoint(nx, ny)
                } else {
                  onDeselectAll()
                }
              }
          )

        ForEach(markers) { marker in
          markerDot(for: marker)
            .position(MarkerOverlayItem.pointInContainer(marker, size: geometry.size))
        }
      }
      .animation(Motion.snappy, value: selectedMarkerNumber)
    }
  }

  private func markerDot(for marker: MarkerOverlayItem) -> some View {
    let isSelected = selectedMarkerNumber == marker.number
    let fillColor = AuthorPalette.color(fromHex: marker.authorColorHex)
    let foregroundColor = AuthorPalette.contrastingForegroundColor(
      forBackgroundHex: marker.authorColorHex
    )

    return Button {
      onSelectMarker(marker.number)
    } label: {
      Text("\(marker.number)")
        .font(Typography.markerNumber)
        .foregroundStyle(foregroundColor)
        .frame(width: DesignMetrics.markerDotSize, height: DesignMetrics.markerDotSize)
        .background(fillColor, in: .circle)
        .overlay {
          Circle()
            .stroke(
              .white,
              lineWidth: isSelected
                ? DesignMetrics.selectedBorderWidth
                : DesignMetrics.hairlineBorderWidth
            )
        }
        .opacity(
          isSelected
            ? DesignMetrics.selectedMarkerOpacity
            : DesignMetrics.unselectedMarkerOpacity
        )
        .scaleEffect(isSelected ? DesignMetrics.selectedMarkerScale : 1)
        .frame(
          width: DesignMetrics.markerHitTargetSize,
          height: DesignMetrics.markerHitTargetSize
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
