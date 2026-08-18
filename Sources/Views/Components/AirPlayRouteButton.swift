#if os(iOS)
    import AVKit
    import SwiftUI

    struct AirPlayRouteButton: UIViewRepresentable {
        let color: Color

        func makeUIView(context: Context) -> AVRoutePickerView {
            let picker = AVRoutePickerView()
            picker.prioritizesVideoDevices = true
            picker.tintColor = UIColor(color)
            picker.activeTintColor = UIColor(color)
            return picker
        }

        func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
            uiView.tintColor = UIColor(color)
            uiView.activeTintColor = UIColor(color)
        }
    }
#endif
