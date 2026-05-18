import SwiftUI

struct HomeView: View {
    @ObservedObject var settings = AppSettings.shared
    @StateObject private var captureManager = AudioCaptureManager()
    @StateObject private var wsClient = SonioxWebSocketClient()
    @StateObject private var subtitleManager = SubtitleManager()
    
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.1, green: 0.12, blue: 0.2), Color(red: 0.15, green: 0.18, blue: 0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 24) {
                    connectionStatusBadge
                    
                    subtitlePreviewBox
                    
                    Spacer()
                    
                    controlButton
                    
                    HStack(spacing: 20) {
                        NavigationLink(destination: BrowserPlayerView(subtitleManager: subtitleManager, captureManager: captureManager)) {
                            HStack {
                                Image(systemName: "globe")
                                Text("Xem Phim")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.35))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.5), lineWidth: 1.5))
                        }
                        
                        NavigationLink(destination: SettingsView()) {
                            HStack {
                                Image(systemName: "gearshape")
                                Text("Cài Đặt")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1.5))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("VTeen Translator")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { subtitleManager.clear() }) {
                        Image(systemName: "trash")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .accentColor(.white)
        .onAppear {
            setupCallbacks()
        }
        .onDisappear {
            stopAll()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Lỗi xảy ra"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private var connectionStatusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .frame(width: 10, height: 10)
                .foregroundColor(statusColor)
            Text(statusText)
                .font(.subheadline)
                .bold()
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.4))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(statusColor.opacity(0.5), lineWidth: 1))
        .padding(.top, 10)
    }
    
    private var subtitlePreviewBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PHỤ ĐỀ THỜI GIAN THỰC")
                .font(.caption)
                .bold()
                .foregroundColor(.gray)
                .padding(.horizontal, 6)
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(subtitleManager.historyLines) { line in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(line.text)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white.opacity(0.6))
                                Text(line.textTranslated)
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundColor(.yellow)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        if !subtitleManager.currentText.isEmpty || !subtitleManager.currentTranslatedText.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(subtitleManager.currentText)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white.opacity(0.4))
                                Text(subtitleManager.currentTranslatedText)
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundColor(.yellow.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("current")
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: .infinity)
                .background(Color.black.opacity(0.3))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .onChange(of: subtitleManager.currentTranslatedText) { _ in
                    withAnimation {
                        proxy.scrollTo("current", anchor: .bottom)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxHeight: 320)
    }
    
    private var controlButton: some View {
        Button(action: toggleCapture) {
            HStack(spacing: 12) {
                Image(systemName: captureManager.isRecording ? "stop.fill" : "mic.fill")
                    .font(.title2)
                Text(captureManager.isRecording ? "DỪNG DỊCH" : "BẮT ĐẦU DỊCH")
                    .font(.headline)
                    .bold()
            }
            .foregroundColor(.white)
            .padding(.vertical, 18)
            .padding(.horizontal, 36)
            .background(captureManager.isRecording ? Color.red : Color.green)
            .cornerRadius(30)
            .shadow(color: (captureManager.isRecording ? Color.red : Color.green).opacity(0.4), radius: 10, y: 5)
            .scaleEffect(captureManager.isRecording ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: captureManager.isRecording)
        }
    }
    
    private var statusColor: Color {
        switch wsClient.connectionState {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .error: return .red
        }
    }
    
    private var statusText: String {
        switch wsClient.connectionState {
        case .disconnected: return "SẴN SÀNG"
        case .connecting: return "ĐANG KẾT NỐI API..."
        case .connected: return "ĐANG DỊCH TRỰC TIẾP..."
        case .error(let err): return "LỖI: \(err)"
        }
    }
    
    private func setupCallbacks() {
        captureManager.onPCMData = { [weak wsClient] data in
            wsClient?.sendAudioChunk(data)
        }
        
        wsClient.onTranslationResult = { [weak subtitleManager] response in
            subtitleManager?.handleSonioxResponse(response)
        }
        
        wsClient.onError = { [weak self] errorStr in
            self?.alertMessage = "Soniox WebSocket Lỗi: \(errorStr)"
            self?.showAlert = true
            self?.stopAll()
        }
    }
    
    private func toggleCapture() {
        if captureManager.isRecording {
            stopAll()
        } else {
            startAll()
        }
    }
    
    private func startAll() {
        let key = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            alertMessage = "Vui lòng vào phần Cài đặt và nhập Soniox API Key để bắt đầu dịch."
            showAlert = true
            return
        }
        
        Task {
            let hasMicPermission = await Permissions.requestMicrophonePermission()
            guard hasMicPermission else {
                alertMessage = "Vui lòng cấp quyền Microphone trong phần Cài đặt hệ thống để tiếp tục."
                showAlert = true
                return
            }
            
            wsClient.connect(apiKey: key, sourceLang: settings.sourceLanguage, targetLang: settings.targetLanguage)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                do {
                    try captureManager.startCapture()
                } catch {
                    alertMessage = "Không thể khởi động bộ thu âm: \(error.localizedDescription)"
                    showAlert = true
                    stopAll()
                }
            }
        }
    }
    
    private func stopAll() {
        captureManager.stopCapture()
        wsClient.disconnect()
    }
}
