import Foundation

final class SubtitleManager: ObservableObject {
    @Published var currentText: String = ""
    @Published var currentTranslatedText: String = ""
    @Published var historyLines: [SubtitleLine] = []
    
    private var silenceTimer: Timer?

    func handleSonioxResponse(_ response: SonioxResponse) {
        guard let words = response.words, !words.isEmpty else { return }
        
        resetSilenceTimer()
        
        let originalText = words.map { $0.text }.joined(separator: " ")
        let translatedText = words.map { $0.textTranslated ?? "" }.joined(separator: " ")
        
        let isFinal = response.final ?? false

        DispatchQueue.main.async {
            if isFinal {
                let finalLine = SubtitleLine(text: originalText, textTranslated: translatedText, isFinal: true)
                self.historyLines.append(finalLine)
                
                if self.historyLines.count > 15 {
                    self.historyLines.removeFirst()
                }
                
                self.currentText = ""
                self.currentTranslatedText = ""
            } else {
                self.currentText = originalText
                self.currentTranslatedText = translatedText
            }
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.currentText = ""
            self.currentTranslatedText = ""
            self.historyLines.removeAll()
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.currentText = ""
                self?.currentTranslatedText = ""
            }
        }
    }
}
