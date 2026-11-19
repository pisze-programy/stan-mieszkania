import Domain
import SwiftUI

public struct MarkerOverlayItem: Identifiable, Sendable, Equatable, Hashable {
  public let id: String
  public let number: Int
  public let x: Double
  public let y: Double
  public let colorHex: String

  public init(
    id: String,
    number: Int,
    x: Double,
    y: Double,
    colorHex: String
  ) {
    self.id = id
    self.number = number
    self.x = x
    self.y = y
    self.colorHex = colorHex
  }

  public static func clampedNormalizedCoordinate(_ value: Double) -> Double {
    min(max(value, ContractConstants.markerCoordMin), ContractConstants.markerCoordMax)
  }

  public static func pointInContainer(_ item: MarkerOverlayItem, size: CGSize) -> CGPoint {
    let clampedX = clampedNormalizedCoordinate(item.x)
    let clampedY = clampedNormalizedCoordinate(item.y)
    return CGPoint(x: clampedX * size.width, y: clampedY * size.height)
  }

  public static func pointInRect(_ item: MarkerOverlayItem, rect: CGRect) -> CGPoint {
    let clampedX = clampedNormalizedCoordinate(item.x)
    let clampedY = clampedNormalizedCoordinate(item.y)
    return CGPoint(
      x: rect.minX + clampedX * rect.width,
      y: rect.minY + clampedY * rect.height
    )
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

public struct MarkerPinBadgeView: View {
  private let marker: MarkerOverlayItem
  private let isSelected: Bool
  private let isDimmed: Bool
  private let onTap: () -> Void

  public init(
    marker: MarkerOverlayItem,
    isSelected: Bool,
    isDimmed: Bool,
    onTap: @escaping () -> Void
  ) {
    self.marker = marker
    self.isSelected = isSelected
    self.isDimmed = isDimmed
    self.onTap = onTap
  }

  public var body: some View {
    let fillColor = AuthorPalette.color(fromHex: marker.colorHex)
    Button(action: onTap) {
      ZStack {
        if isSelected {
          Circle()
            .stroke(
              fillColor.opacity(DesignMetrics.markerHaloOpacity),
              lineWidth: DesignMetrics.markerHaloStrokeWidth
            )
            .frame(width: DesignMetrics.markerDotSize, height: DesignMetrics.markerDotSize)
        }

        Text("\(marker.number)")
          .font(.caption.weight(.bold).monospacedDigit())
          .foregroundStyle(.white)
          .frame(width: DesignMetrics.markerDotSize, height: DesignMetrics.markerDotSize)
          .background(fillColor, in: .circle)
          .overlay {
            Circle()
              .stroke(.white, lineWidth: DesignMetrics.markerPinStrokeWidth)
          }
          .shadow(
            color: .black.opacity(DesignMetrics.markerShadowOpacity),
            radius: DesignMetrics.markerShadowRadius,
            y: DesignMetrics.markerShadowYOffset
          )
      }
      .scaleEffect(isSelected ? DesignMetrics.selectedMarkerScale : 1)
      .opacity(isDimmed ? DesignMetrics.dimmedMarkerOpacity : DesignMetrics.selectedMarkerOpacity)
      .frame(
        width: DesignMetrics.markerHitTargetSize,
        height: DesignMetrics.markerHitTargetSize
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

public struct MarkerDotOverlayView: View {
  private let markers: [MarkerOverlayItem]
  private let selectedMarkerNumber: Int?
  private let onSelectMarker: (Int) -> Void
  private let onDeselectAll: (() -> Void)?
  private let onAddMarkerAtNormalizedPoint: ((Double, Double) -> Void)?

  public init(
    markers: [MarkerOverlayItem],
    selectedMarkerNumber: Int?,
    onSelectMarker: @escaping (Int) -> Void,
    onDeselectAll: (() -> Void)? = nil,
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
        if onAddMarkerAtNormalizedPoint != nil || onDeselectAll != nil {
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
                    onDeselectAll?()
                  }
                }
            )
        }

        ForEach(markers) { marker in
          let isSelected = selectedMarkerNumber == marker.number
          let isDimmed = selectedMarkerNumber != nil && !isSelected
          MarkerPinBadgeView(
            marker: marker,
            isSelected: isSelected,
            isDimmed: isDimmed,
            onTap: { onSelectMarker(marker.number) }
          )
          .position(MarkerOverlayItem.pointInContainer(marker, size: geometry.size))
        }
      }
      .animation(Motion.snappy, value: selectedMarkerNumber)
    }
  }
}
