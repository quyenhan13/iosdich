import SwiftUI

struct HomeView: View {
    @ObservedObject var settings = AppSettings.shared
    @StateObject private var captureManager = AudioCaptureManager()
    @StateObject private var wsClient = SonioxWebSocketClient()
    @StateObject private var subtitleManager = SubtitleManager()

    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var isMiniMode = false

    var body: some View {
        NavigationView {
            ZStack {
                TransifyrBackground()

                if isMiniMode && captureManager.isRecording {
                    miniListeningView
                        .transition(.scale.combined(with: .opacity))
                } else {
                    VStack(spacing: 14) {
                        header
                        tabBar
                        listenPanel
                        consolePanel
                        footer
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 10)
                    .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isMiniMode)
            .navigationBarHidden(true)
        }
        .accentColor(.white)
        .onAppear(perform: setupCallbacks)
        .onDisappear(perform: stopAll)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Lỗi xảy ra"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private var miniListeningView: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                ZStack(alignment: .topTrailing) {
                    Button {
                        isMiniMode = false
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 58, height: 58)
                            .background(TransifyrTheme.accentGradient)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                            .shadow(color: TransifyrTheme.accent.opacity(0.55), radius: 18, y: 8)
                    }
                    .buttonStyle(.plain)

                    Button(action: stopAll) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(TransifyrTheme.dangerGradient)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.65), lineWidth: 1))
                    }
                    .offset(x: 6, y: -6)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(TransifyrTheme.accentGradient)
                    .frame(width: 42, height: 42)
                    .shadow(color: TransifyrTheme.accent.opacity(0.45), radius: 12)
                Image(systemName: "captions.bubble.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Transifyr")
                        .font(.system(size: 22, weight: .black))
                    Text("Lite")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(TransifyrTheme.accentGradient)
                }
                Text("Realtime subtitle translator")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(TransifyrTheme.textSecondary)
                    .textCase(.uppercase)
            }

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.8), radius: 6)
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(TransifyrTheme.input)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(TransifyrTheme.border, lineWidth: 1))
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton(title: "Dịch thuật", icon: "message.fill", active: true) {}

            NavigationLink(destination: SettingsView()) {
                tabLabel(title: "Cài đặt", icon: "gearshape.fill", active: false)
            }

            NavigationLink(destination: BrowserPlayerView(subtitleManager: subtitleManager, captureManager: captureManager)) {
                tabLabel(title: "Xem phim", icon: "play.rectangle.fill", active: false)
            }
        }
        .padding(4)
        .background(TransifyrTheme.input.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(TransifyrTheme.border, lineWidth: 1))
    }

    private var listenPanel: some View {
        VStack(spacing: 14) {
            ZStack {
                if captureManager.isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.16))
                        .frame(width: 176, height: 176)
                        .scaleEffect(1.15)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: captureManager.isRecording)
                }

                Button(action: toggleCapture) {
                    HStack(spacing: 10) {
                        Image(systemName: captureManager.isRecording ? "stop.fill" : "mic.fill")
                        Text(captureManager.isRecording ? "Dừng dịch" : "Bắt đầu lắng nghe")
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(captureManager.isRecording ? TransifyrTheme.dangerGradient : TransifyrTheme.accentGradient)
                    .clipShape(Capsule())
                    .shadow(color: (captureManager.isRecording ? Color.red : TransifyrTheme.accent).opacity(0.4), radius: 18, y: 8)
                }
            }
            .frame(height: 100)
        }
    }

    private var consolePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Xem trước phụ đề")
                    .font(.caption.weight(.bold))
                    .foregroundColor(TransifyrTheme.textSecondary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: subtitleManager.clear) {
                    Text("Xóa log")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(TransifyrTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(TransifyrTheme.input)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("[Hệ thống] Transifyr Lite sẵn sàng hoạt động.")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(TransifyrTheme.accentLight)

                        ForEach(subtitleManager.historyLines) { line in
                            logBlock(original: line.text, translated: line.textTranslated)
                        }

                        if !subtitleManager.currentText.isEmpty || !subtitleManager.currentTranslatedText.isEmpty {
                            logBlock(original: subtitleManager.currentText, translated: subtitleManager.currentTranslatedText, live: true)
                                .id("current")
                        }
                    }
                    .padding(14)
                }
                .background(Color.black.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                .onChange(of: subtitleManager.currentTranslatedText) { _ in
                    withAnimation { proxy.scrollTo("current", anchor: .bottom) }
                }
            }
        }
        .padding(16)
        .frame(maxHeight: .infinity)
        .background(TransifyrTheme.glass)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(TransifyrTheme.borderLight, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
    }

    private var footer: some View {
        Text("Phiên bản 1.0.0 • Soniox realtime • VTeen")
            .font(.caption2)
            .foregroundColor(TransifyrTheme.textMuted)
    }

    private func logBlock(original: String, translated: String, live: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if !original.isEmpty {
                Text(original)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(TransifyrTheme.textSecondary)
                    .padding(.leading, 8)
                    .overlay(Rectangle().fill(TransifyrTheme.accent.opacity(0.45)).frame(width: 2), alignment: .leading)
            }
            if !translated.isEmpty {
                Text(translated)
                    .font(.system(size: live ? 19 : 17, weight: .bold))
                    .foregroundColor(.cyan)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
        .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .bottom)
    }

    private func tabButton(title: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            tabLabel(title: title, icon: icon, active: active)
        }
    }

    private func tabLabel(title: String, icon: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
        }
        .foregroundColor(active ? .white : TransifyrTheme.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(active ? AnyShapeStyle(TransifyrTheme.accentGradient) : AnyShapeStyle(Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var statusColor: Color {
        switch wsClient.connectionState {
        case .disconnected: return TransifyrTheme.textSecondary
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }

    private var statusText: String {
        switch wsClient.connectionState {
        case .disconnected: return "Sẵn sàng"
        case .connecting: return "Đang kết nối"
        case .connected: return "Đang dịch"
        case .error: return "Lỗi"
        }
    }

    private func setupCallbacks() {
        captureManager.onPCMData = { [weak wsClient] data in
            wsClient?.sendAudioChunk(data)
        }

        wsClient.onTranslationResult = { [weak subtitleManager] response in
            subtitleManager?.handleSonioxResponse(response)
        }

        wsClient.onError = { errorStr in
            self.alertMessage = "Soniox WebSocket lỗi: \(errorStr)"
            self.showAlert = true
            self.stopAll()
        }
    }

    private func toggleCapture() {
        captureManager.isRecording ? stopAll() : startAll()
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
                alertMessage = "Vui lòng cấp quyền Microphone trong Cài đặt hệ thống."
                showAlert = true
                return
            }

            wsClient.connect(apiKey: key, sourceLang: settings.sourceLanguage, targetLang: settings.targetLanguage)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                do {
                    try captureManager.startCapture()
                    isMiniMode = true
                } catch {
                    alertMessage = "Không thể khởi động bộ thu âm: \(error.localizedDescription)"
                    showAlert = true
                    stopAll()
                }
            }
        }
    }

    private func stopAll() {
        isMiniMode = false
        captureManager.stopCapture()
        wsClient.disconnect()
    }
}

struct TransifyrBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.035, blue: 0.09)
            LinearGradient(
                colors: [
                    TransifyrTheme.accent.opacity(0.22),
                    Color(red: 0.85, green: 0.28, blue: 0.94).opacity(0.08),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottomLeading
            )
        }
        .ignoresSafeArea()
    }
}

enum TransifyrTheme {
    static let accent = Color(red: 0.55, green: 0.36, blue: 0.96)
    static let accentLight = Color(red: 0.65, green: 0.55, blue: 0.98)
    static let textSecondary = Color(red: 0.58, green: 0.64, blue: 0.72)
    static let textMuted = Color(red: 0.39, green: 0.45, blue: 0.55)
    static let glass = Color(red: 0.07, green: 0.065, blue: 0.14).opacity(0.78)
    static let input = Color.white.opacity(0.045)
    static let border = Color.white.opacity(0.06)
    static let borderLight = accent.opacity(0.22)

    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.86, green: 0.28, blue: 0.94)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dangerGradient = LinearGradient(
        colors: [Color(red: 0.94, green: 0.27, blue: 0.27), Color(red: 0.95, green: 0.24, blue: 0.37)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
