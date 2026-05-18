import Foundation
import CoreMedia
import AVKit
import Combine
import SwiftUI

final class SystemSubtitleOverlayManager: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var isSupported = true // CAWindowServer is supported on TrollStore

    // Dummy layer for HomeView
    let displayLayer = AVSampleBufferDisplayLayer()

    private var rootLayer: CALayer?
    private var textLayer: CATextLayer?
    private var bgLayer: CALayer?
    
    private var overlayContext: NSObject?
    private var mainDisplay: NSObject?

    private var hideTimer: Timer?
    
    // Background keep-alive
    private var audioPlayer: AVAudioPlayer?

    override init() {
        super.init()
        displayLayer.backgroundColor = UIColor.clear.cgColor
        setupSilentAudio()
    }
    
    private func setupSilentAudio() {
        // Create 1 second of silence
        let bytes: [UInt8] = [UInt8](repeating: 0, count: 44100 * 2 * 2)
        let data = Data(bytes)
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.01
        } catch {
            Logger.log("Silent audio failed", level: .error)
        }
    }

    func start() {
        guard !isRunning else { return }
        
        do {
            try AudioSessionManager.configureForPlaybackOverlay()
            audioPlayer?.play()
        } catch { }

        // CAWindowServer Setup
        let CAWindowServer = NSClassFromString("CAWindowServer") as? NSObjectProtocol
        guard let server = CAWindowServer?.perform(NSSelectorFromString("serverIfRunning"))?.takeUnretainedValue() as? NSObject else {
            Logger.log("Failed to get CAWindowServer", level: .error)
            return
        }
        
        guard let displays = server.value(forKey: "displays") as? [NSObject],
              let mainDisp = displays.first else {
            Logger.log("Failed to get displays", level: .error)
            return
        }
              
        let CAContext = NSClassFromString("CAContext") as? NSObjectProtocol
        let options: [String: Any] = [
            "secure": true
        ]
        
        guard let context = CAContext?.perform(NSSelectorFromString("remoteContextWithOptions:"), with: options)?.takeUnretainedValue() as? NSObject else {
            Logger.log("Failed to create CAContext", level: .error)
            return
        }
        
        // Setup Overlay Layers
        let screenBounds = UIScreen.main.bounds
        let container = CALayer()
        container.frame = CGRect(x: 0, y: screenBounds.height - 250, width: screenBounds.width, height: 160)
        
        let bg = CALayer()
        bg.frame = CGRect(x: 20, y: 0, width: screenBounds.width - 40, height: 160)
        bg.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
        bg.cornerRadius = 12
        bg.opacity = 0.0
        container.addSublayer(bg)
        
        let text = CATextLayer()
        text.frame = CGRect(x: 30, y: 15, width: screenBounds.width - 60, height: 130)
        text.fontSize = 18
        text.foregroundColor = UIColor.white.cgColor
        text.alignmentMode = .center
        text.isWrapped = true
        text.contentsScale = UIScreen.main.scale
        text.string = ""
        container.addSublayer(text)
        
        context.setValue(container, forKey: "layer")
        mainDisp.perform(NSSelectorFromString("addClient:"), with: context)
        
        self.rootLayer = container
        self.bgLayer = bg
        self.textLayer = text
        self.overlayContext = context
        self.mainDisplay = mainDisp
        
        DispatchQueue.main.async {
            self.isRunning = true
        }
    }

    func stop() {
        audioPlayer?.stop()
        hideTimer?.invalidate()
        
        if let ctx = overlayContext, let mainDisp = mainDisplay {
            mainDisp.perform(NSSelectorFromString("removeClient:"), with: ctx)
        }
        
        self.rootLayer = nil
        self.bgLayer = nil
        self.textLayer = nil
        self.overlayContext = nil
        self.mainDisplay = nil
        
        DispatchQueue.main.async {
            self.isRunning = false
        }
    }

    func update(text: String, translation: String) {
        guard isRunning else { return }
        
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTranslation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanText.isEmpty && cleanTranslation.isEmpty { return }
        
        let fullText = cleanTranslation.isEmpty ? cleanText : "\(cleanText)\n\n\(cleanTranslation)"
        
        DispatchQueue.main.async {
            self.textLayer?.string = fullText
            self.bgLayer?.opacity = 1.0
            
            self.hideTimer?.invalidate()
            self.hideTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { [weak self] _ in
                self?.textLayer?.string = ""
                self?.bgLayer?.opacity = 0.0
            }
        }
    }
}
