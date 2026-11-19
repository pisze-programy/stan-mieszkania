import CoreFoundation

public enum DesignMetrics: Sendable {
  public static let hairlineBorderWidth: CGFloat = 1
  public static let selectedBorderWidth: CGFloat = 2

  public static let avatarSmallSize: CGFloat = 24
  public static let entryAuthorAvatarSize: CGFloat = 28
  public static let avatarMediumSize: CGFloat = 32
  public static let avatarLargeSize: CGFloat = 44
  public static let badgeHeight: CGFloat = 22
  public static let progressRingSize: CGFloat = 20

  public static let iconSmallSize: CGFloat = 14
  public static let iconMediumSize: CGFloat = 20
  public static let iconLargeSize: CGFloat = 28
  public static let glassIconButtonSize: CGFloat = 44
  public static let floatingActionButtonSize: CGFloat = 56

  public static let timelineThumbnailMinWidth: CGFloat = 104
  public static let timelineThumbnailAspectRatio: CGFloat = 1

  public static let markerDotSize: CGFloat = 28
  public static let markerHitTargetSize: CGFloat = 44
  public static let markerPinStrokeWidth: CGFloat = 2
  public static let markerHaloStrokeWidth: CGFloat = 6
  public static let markerHaloOpacity: Double = 0.35
  public static let markerShadowOpacity: Double = 0.35
  public static let markerShadowRadius: CGFloat = 3
  public static let markerShadowYOffset: CGFloat = 1
  public static let dimmedMarkerOpacity: Double = 0.55
  public static let selectedMarkerOpacity: Double = 1.0
  public static let selectedMarkerScale: CGFloat = 1.25

  public static let disabledOpacity: Double = 0.45
  public static let tombstoneOpacity: Double = 0.6
  public static let stableSlotMinHeight: CGFloat = 20
}
