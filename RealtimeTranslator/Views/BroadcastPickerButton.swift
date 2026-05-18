import ReplayKit
import SwiftUI

struct BroadcastPickerButton: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: .zero)
        picker.preferredExtension = "com.vteen.RealtimeTranslator.Broadcast"
        picker.showsMicrophoneButton = false

        if let button = picker.subviews.compactMap({ $0 as? UIButton }).first {
            button.setImage(UIImage(systemName: "waveform.circle.fill"), for: .normal)
            button.tintColor = .white
        }

        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
