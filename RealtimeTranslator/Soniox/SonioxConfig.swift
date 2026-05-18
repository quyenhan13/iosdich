import Foundation

struct SonioxConfig: Codable {
    let apiKey: String
    let model: String
    let audioFormat: String
    let sampleRate: Int
    let numChannels: Int
    let translation: TranslationConfig?

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case model
        case audioFormat = "audio_format"
        case sampleRate = "sample_rate"
        case numChannels = "num_channels"
        case translation
    }
}

struct TranslationConfig: Codable {
    let type: String
    let targetLanguage: String

    enum CodingKeys: String, CodingKey {
        case type
        case targetLanguage = "target_language"
    }
}
