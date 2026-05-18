import SwiftUI
import WebKit

struct WebViewRepresentable: UIViewRepresentable {
    let urlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let url = URL(string: urlString) else { return }
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}

struct BrowserPlayerView: View {
    @State private var urlInput = "https://m.youtube.com"
    @State private var activeURL = "https://m.youtube.com"
    @ObservedObject var subtitleManager: SubtitleManager
    @ObservedObject var captureManager: AudioCaptureManager
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Nhập URL trang phim/web...", text: $urlInput, onCommit: {
                    var formatted = urlInput
                    if !formatted.lowercased().hasPrefix("http://") && !formatted.lowercased().hasPrefix("https://") {
                        formatted = "https://" + formatted
                    }
                    activeURL = formatted
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.URL)
                
                Button(action: {
                    var formatted = urlInput
                    if !formatted.lowercased().hasPrefix("http://") && !formatted.lowercased().hasPrefix("https://") {
                        formatted = "https://" + formatted
                    }
                    activeURL = formatted
                }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            ZStack(alignment: .bottom) {
                WebViewRepresentable(urlString: activeURL)
                    .edgesIgnoringSafeArea(.bottom)
                
                if !subtitleManager.currentTranslatedText.isEmpty || !subtitleManager.currentText.isEmpty {
                    SubtitleOverlayView(
                        text: subtitleManager.currentText,
                        translation: subtitleManager.currentTranslatedText
                    )
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Trình Duyệt & Xem Phim")
        .navigationBarTitleDisplayMode(.inline)
    }
}
