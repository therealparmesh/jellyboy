import AVFoundation
import SwiftUI

#if os(iOS)
    import UIKit

    struct NativePlayerSurface: UIViewRepresentable {
        let player: AVPlayer

        func makeUIView(context: Context) -> NativePlayerView {
            let view = NativePlayerView()
            view.playerLayer.player = player
            return view
        }

        func updateUIView(_ uiView: NativePlayerView, context: Context) {
            uiView.playerLayer.player = player
        }
    }

    final class NativePlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer {
            guard let layer = layer as? AVPlayerLayer else {
                preconditionFailure("NativePlayerView must use AVPlayerLayer")
            }
            layer.videoGravity = .resizeAspect
            return layer
        }
    }
#elseif os(macOS)
    import AppKit

    struct NativePlayerSurface: NSViewRepresentable {
        let player: AVPlayer

        func makeNSView(context: Context) -> NativePlayerView {
            let view = NativePlayerView()
            view.playerLayer.player = player
            return view
        }

        func updateNSView(_ nsView: NativePlayerView, context: Context) {
            nsView.playerLayer.player = player
        }
    }

    final class NativePlayerView: NSView {
        override func makeBackingLayer() -> CALayer {
            let layer = AVPlayerLayer()
            layer.videoGravity = .resizeAspect
            return layer
        }

        var playerLayer: AVPlayerLayer {
            wantsLayer = true
            guard let layer = layer as? AVPlayerLayer else {
                preconditionFailure("NativePlayerView must use AVPlayerLayer")
            }
            return layer
        }
    }
#endif
