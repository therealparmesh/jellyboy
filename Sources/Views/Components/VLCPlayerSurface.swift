import SwiftUI

#if os(iOS)
    import UIKit

    struct VLCPlayerSurface: UIViewRepresentable {
        let coordinator: PlaybackCoordinator

        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            view.backgroundColor = .black
            coordinator.attachVLCDrawable(view)
            return view
        }

        func updateUIView(_ uiView: UIView, context: Context) {
            coordinator.attachVLCDrawable(uiView)
        }
    }
#elseif os(macOS)
    import AppKit

    struct VLCPlayerSurface: NSViewRepresentable {
        let coordinator: PlaybackCoordinator

        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.black.cgColor
            coordinator.attachVLCDrawable(view)
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            coordinator.attachVLCDrawable(nsView)
        }
    }
#endif
