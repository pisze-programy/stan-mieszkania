import Domain
import SwiftUI

public struct AuthorAvatarView: View {
  private static let roleBadgeOpacity: Double = 0.14
  private static let fontScaleFactor: CGFloat = 0.42

  private let displayName: String
  private let colorHex: String
  private let role: MemberRole?
  private let size: CGFloat
  private let showsRoleBadge: Bool

  public init(
    displayName: String,
    colorHex: String,
    role: MemberRole? = nil,
    size: CGFloat = DesignMetrics.avatarMediumSize,
    showsRoleBadge: Bool = false
  ) {
    self.displayName = displayName
    self.colorHex = colorHex
    self.role = role
    self.size = size
    self.showsRoleBadge = showsRoleBadge
  }

  public var body: some View {
    HStack(spacing: Spacing.xs) {
      avatarCircle
      if showsRoleBadge, let role {
        roleBadge(for: role)
      }
    }
  }

  private var avatarCircle: some View {
    Text(AuthorBadgePolicy.initials(for: displayName))
      .font(.system(size: size * Self.fontScaleFactor, weight: .bold))
      .foregroundStyle(AuthorPalette.contrastingForegroundColor(forBackgroundHex: colorHex))
      .frame(width: size, height: size)
      .background(AuthorPalette.color(fromHex: colorHex), in: .circle)
      .accessibilityLabel(displayName)
  }

  private func roleBadge(for role: MemberRole) -> some View {
    let title =
      switch role {
      case .owner:
        L10n.string("media.detail.role.owner")
      case .contributor:
        L10n.string("media.detail.role.contributor")
      }

    return Text(title)
      .font(Typography.badge)
      .foregroundStyle(.secondary)
      .padding(.horizontal, Spacing.xs)
      .padding(.vertical, Spacing.xxs)
      .background(.secondary.opacity(Self.roleBadgeOpacity), in: .capsule)
  }
}
