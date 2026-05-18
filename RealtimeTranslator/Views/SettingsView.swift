import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var apiKeyInput: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    let languages = [
        ("auto", "Tự động phát hiện (Auto)"),
        ("en", "English (Mỹ)"),
        ("zh", "Chinese (Trung)"),
        ("ja", "Japanese (Nhật)"),
        ("ko", "Korean (Hàn)"),
        ("vi", "Vietnamese (Việt)")
    ]
    
    let targetLanguages = [
        ("vi", "Tiếng Việt 🇻🇳"),
        ("en", "Tiếng Anh 🇺🇸")
    ]

    var body: some View {
        Form {
            Section(header: Text("Tài khoản & API").foregroundColor(.blue)) {
                SecureField("Soniox API Key", text: $apiKeyInput)
                    .onAppear {
                        apiKeyInput = settings.apiKey
                    }
                
                Button(action: {
                    settings.apiKey = apiKeyInput
                    alertMessage = "Đã lưu API Key thành công!"
                    showAlert = true
                }) {
                    HStack {
                        Spacer()
                        Text("Lưu API Key")
                            .bold()
                        Spacer()
                    }
                }
            }
            
            Section(header: Text("Cấu hình ngôn ngữ dịch").foregroundColor(.blue)) {
                Picker("Ngôn ngữ gốc", selection: $settings.sourceLanguage) {
                    ForEach(languages, id: \.0) { lang in
                        Text(lang.1).tag(lang.0)
                    }
                }
                
                Picker("Dịch sang", selection: $settings.targetLanguage) {
                    ForEach(targetLanguages, id: \.0) { lang in
                        Text(lang.1).tag(lang.0)
                    }
                }
            }
            
            Section(header: Text("Giao diện phụ đề").foregroundColor(.blue)) {
                Picker("Style phụ đề", selection: $settings.overlayStyle) {
                    ForEach(SubtitleStyle.allCases, id: \.rawValue) { style in
                        Text(style.rawValue).tag(style.rawValue)
                    }
                }
            }
            
            Section(header: Text("Thông tin Soniox SDK")) {
                HStack {
                    Text("Model STT")
                    Spacer()
                    Text("stt-rt-v4")
                        .foregroundColor(.gray)
                }
                HStack {
                    Text("Phiên bản App")
                    Spacer()
                    Text("1.0.0 (MVP)")
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle("Cài Đặt")
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Thông báo"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
}
