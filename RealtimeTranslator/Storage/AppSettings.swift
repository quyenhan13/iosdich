import Foundation

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var sourceLanguage: String {
        didSet {
            UserDefaults.standard.set(sourceLanguage, forKey: "source_language")
            groupDefaults?.set(sourceLanguage, forKey: "source_language")
            groupDefaults?.synchronize()
        }
    }
    
    @Published var targetLanguage: String {
        didSet {
            UserDefaults.standard.set(targetLanguage, forKey: "target_language")
            groupDefaults?.set(targetLanguage, forKey: "target_language")
            groupDefaults?.synchronize()
        }
    }
    
    @Published var overlayStyle: String {
        didSet { UserDefaults.standard.set(overlayStyle, forKey: "overlay_style") }
    }

    private let groupDefaults = UserDefaults(suiteName: "group.com.vteen.RealtimeTranslator")

    private init() {
        self.sourceLanguage = UserDefaults.standard.string(forKey: "source_language") ?? "auto"
        self.targetLanguage = UserDefaults.standard.string(forKey: "target_language") ?? "vi"
        self.overlayStyle = UserDefaults.standard.string(forKey: "overlay_style") ?? "Classic"
        _ = syncSharedSettings()
    }
    
    var apiKey: String {
        get {
            KeychainStore.shared.load(forKey: "soniox_api_key")
                ?? UserDefaults.standard.string(forKey: "soniox_api_key_fallback")
                ?? ""
        }
        set {
            _ = saveAPIKey(newValue)
        }
    }

    @discardableResult
    func saveAPIKey(_ value: String) -> Bool {
        let cleanedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(cleanedValue, forKey: "soniox_api_key_fallback")
        groupDefaults?.set(cleanedValue, forKey: "soniox_api_key_fallback")
        let savedToKeychain = KeychainStore.shared.save(cleanedValue, forKey: "soniox_api_key")
        _ = syncSharedSettings()
        Logger.log(savedToKeychain ? "Đã lưu API Key vào Keychain." : "Keychain lỗi, đã lưu API Key vào UserDefaults fallback.")
        return savedToKeychain
    }

    @discardableResult
    func syncSharedSettings() -> Bool {
        let key = (
            KeychainStore.shared.load(forKey: "soniox_api_key")
            ?? UserDefaults.standard.string(forKey: "soniox_api_key_fallback")
            ?? groupDefaults?.string(forKey: "soniox_api_key_fallback")
            ?? ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        if !key.isEmpty {
            UserDefaults.standard.set(key, forKey: "soniox_api_key_fallback")
            groupDefaults?.set(key, forKey: "soniox_api_key_fallback")
        }

        UserDefaults.standard.set(sourceLanguage, forKey: "source_language")
        UserDefaults.standard.set(targetLanguage, forKey: "target_language")
        groupDefaults?.set(sourceLanguage, forKey: "source_language")
        groupDefaults?.set(targetLanguage, forKey: "target_language")
        UserDefaults.standard.synchronize()
        groupDefaults?.synchronize()
        return !key.isEmpty
    }
}
