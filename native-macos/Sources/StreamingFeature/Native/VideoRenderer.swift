import CoreGraphics
import SwiftUI

@MainActor
public final class VideoRenderer: ObservableObject, @unchecked Sendable {
    @Published public private(set) var statusText: String
    @Published public private(set) var frameSize: CGSize?
    @Published public private(set) var attachedTrackID: String?

    public init(
        statusText: String = "Renderer idle",
        frameSize: CGSize? = nil,
        attachedTrackID: String? = nil
    ) {
        self.statusText = statusText
        self.frameSize = frameSize
        self.attachedTrackID = attachedTrackID
    }

    public func attach(trackID: String, frameSize: CGSize = CGSize(width: 1280, height: 720)) {
        attachedTrackID = trackID
        self.frameSize = frameSize
        statusText = "Rendering native video"
    }

    public func markStreamingActive() {
        statusText = "Native stream active"
    }

    public func reset() {
        attachedTrackID = nil
        frameSize = nil
        statusText = "Renderer idle"
    }
}

public struct NativeVideoSurfaceView: View {
    @ObservedObject private var renderer: VideoRenderer

    public init(renderer: VideoRenderer) {
        self.renderer = renderer
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.92), Color.cyan.opacity(0.32)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 10) {
                Image(systemName: "display.2")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.92))

                Text(renderer.statusText)
                    .font(.headline)
                    .foregroundStyle(.white)

                if let frameSize = renderer.frameSize {
                    Text("\(Int(frameSize.width)) × \(Int(frameSize.height))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding()
        }
    }
}
