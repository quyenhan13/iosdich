import Foundation

struct SonioxResponse: Codable {
    let words: [SonioxWord]?
    let final: Bool?
    let error: String?
}

struct SonioxWord: Codable, Identifiable {
    var id: String { text + "\(startMs)" }
    let text: String
    let startMs: Int
    let durationMs: Int
    let isFinal: Bool?
    let textTranslated: String?

    enum CodingKeys: String, CodingKey {
        case text
        case startMs = "start_ms"
        case durationMs = "duration_ms"
        case isFinal = "is_final"
        case textTranslated = "text_translated"
    }
}
