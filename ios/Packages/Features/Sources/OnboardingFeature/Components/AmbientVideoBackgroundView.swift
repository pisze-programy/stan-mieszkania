import AVFoundation
import SwiftUI

public struct AmbientVideoBackgroundView: View {
  private static let gridDimension: Int = 3
  private static let animationSpeed: Double = 0.25
  private static let meshDriftAmplitude: Float = 0.08
  private static let scrimTopOpacity: Double = 0.25
  private static let scrimBottomOpacity: Double = 0.72
  private static let halfCoordinate: Float = 0.5
  private static let meshBaseColorHex: Double = 0.06
  private static let meshAccentRed: Double = 0.08
  private static let meshAccentGreen: Double = 0.18
  private static let meshAccentBlue: Double = 0.34
  private static let meshHighlightRed: Double = 0.10
  private static let meshHighlightGreen: Double = 0.28
  private static let meshHighlightBlue: Double = 0.42

  private let videoURL: URL?

  public init(videoURL: URL? = nil) {
    self.videoURL = videoURL
  }

  public var body: some View {
    ZStack {
      if let videoURL {
        LoopingVideoPlayerView(videoURL: videoURL)
      } else {
        fallbackAnimatedBackdrop
      }
      LinearGradient(
        colors: [
          .black.opacity(Self.scrimTopOpacity),
          .black.opacity(Self.scrimBottomOpacity),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    }
    .ignoresSafeArea()
  }

  private var fallbackAnimatedBackdrop: some View {
    TimelineView(.animation) { context in
      let phase = Float(context.date.timeIntervalSinceReferenceDate * Self.animationSpeed)
      let centerX = Self.halfCoordinate + Self.meshDriftAmplitude * sin(phase)
      let centerY = Self.halfCoordinate + Self.meshDriftAmplitude * cos(phase)
      let base = Color(
        red: Self.meshBaseColorHex,
        green: Self.meshBaseColorHex,
        blue: Self.meshBaseColorHex
      )
      let accent = Color(
        red: Self.meshAccentRed,
        green: Self.meshAccentGreen,
        blue: Self.meshAccentBlue
      )
      let highlight = Color(
        red: Self.meshHighlightRed,
        green: Self.meshHighlightGreen,
        blue: Self.meshHighlightBlue
      )

      MeshGradient(
        width: Self.gridDimension,
        height: Self.gridDimension,
        points: [
          SIMD2(0, 0), SIMD2(Self.halfCoordinate, 0), SIMD2(1, 0),
          SIMD2(0, Self.halfCoordinate), SIMD2(centerX, centerY), SIMD2(1, Self.halfCoordinate),
          SIMD2(0, 1), SIMD2(Self.halfCoordinate, 1), SIMD2(1, 1),
        ],
        colors: [
          base, accent, base,
          accent, highlight, accent,
          base, accent, base,
        ]
      )
    }
  }
}

#if os(iOS)
  private struct LoopingVideoPlayerView: UIViewRepresentable {
    let videoURL: URL

    func makeUIView(context: Context) -> PlayerContainerUIView {
      PlayerContainerUIView(videoURL: videoURL)
    }

    func updateUIView(_ uiView: PlayerContainerUIView, context: Context) {
      uiView.updateVideoURL(videoURL)
    }
  }

  private final class PlayerContainerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var currentURL: URL?

    init(videoURL: URL) {
      super.init(frame: .zero)
      playerLayer.videoGravity = .resizeAspectFill
      layer.addSublayer(playerLayer)
      updateVideoURL(videoURL)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      nil
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      playerLayer.frame = bounds
    }

    func updateVideoURL(_ url: URL) {
      guard currentURL != url else {
        return
      }
      currentURL = url
      let item = AVPlayerItem(url: url)
      let player = AVQueuePlayer(playerItem: item)
      player.isMuted = true
      player.allowsExternalPlayback = false
      let looper = AVPlayerLooper(player: player, templateItem: item)
      playerLayer.player = player
      queuePlayer = player
      playerLooper = looper
      player.play()
    }
  }
#elseif os(macOS)
  private struct LoopingVideoPlayerView: NSViewRepresentable {
    let videoURL: URL

    func makeNSView(context: Context) -> PlayerContainerNSView {
      PlayerContainerNSView(videoURL: videoURL)
    }

    func updateNSView(_ nsView: PlayerContainerNSView, context: Context) {
      nsView.updateVideoURL(videoURL)
    }
  }

  private final class PlayerContainerNSView: NSView {
    private let playerLayer = AVPlayerLayer()
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var currentURL: URL?

    init(videoURL: URL) {
      super.init(frame: .zero)
      wantsLayer = true
      playerLayer.videoGravity = .resizeAspectFill
      layer?.addSublayer(playerLayer)
      updateVideoURL(videoURL)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      nil
    }

    override func layout() {
      super.layout()
      playerLayer.frame = bounds
    }

    func updateVideoURL(_ url: URL) {
      guard currentURL != url else {
        return
      }
      currentURL = url
      let item = AVPlayerItem(url: url)
      let player = AVQueuePlayer(playerItem: item)
      player.isMuted = true
      let looper = AVPlayerLooper(player: player, templateItem: item)
      playerLayer.player = player
      queuePlayer = player
      playerLooper = looper
      player.play()
    }
  }
#endif
