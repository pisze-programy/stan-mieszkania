import SwiftUI

public enum Motion: Sendable {
  private static let snappyResponse: Double = 0.28
  private static let snappyDamping: Double = 0.85
  private static let smoothResponse: Double = 0.38
  private static let smoothDamping: Double = 0.88
  private static let gentleResponse: Double = 0.5
  private static let gentleDamping: Double = 0.92

  public static let snappy: Animation = .spring(
    response: snappyResponse,
    dampingFraction: snappyDamping
  )
  public static let smooth: Animation = .spring(
    response: smoothResponse,
    dampingFraction: smoothDamping
  )
  public static let gentle: Animation = .spring(
    response: gentleResponse,
    dampingFraction: gentleDamping
  )
}
