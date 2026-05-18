import AVFoundation
import CoreMedia
import ReplayKit

final class SampleHandler: RPBroadcastSampleHandler {
    private static let appGroupID = "group.com.vteen.RealtimeTranslator"
    private let client = BroadcastSonioxClient()
    private let converter = BroadcastPCMConverter()
    private let defaults = UserDefaults(suiteName: appGroupID)

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        let sharedSettings = loadSharedSettingsFile()
        let apiKey = firstNonEmpty(
            defaults?.string(forKey: "soniox_api_key_fallback"),
            sharedSettings["soniox_api_key_fallback"] as? String
        ) ?? ""
        let sourceLang = firstNonEmpty(
            defaults?.string(forKey: "source_language"),
            sharedSettings["source_language"] as? String
        ) ?? "auto"
        let targetLang = firstNonEmpty(
            defaults?.string(forKey: "target_language"),
            sharedSettings["target_language"] as? String
        ) ?? "vi"

        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            finishBroadcastWithError(NSError(domain: "TransifyrBroadcast", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Chưa có Soniox API Key. Mở app Transifyr và lưu key trước."
            ]))
            return
        }

        client.onTranslation = { [weak self] original, translation in
            self?.defaults?.set(original, forKey: "broadcast_current_original")
            self?.defaults?.set(translation, forKey: "broadcast_current_translation")
            self?.defaults?.set(Date().timeIntervalSince1970, forKey: "broadcast_current_translation_at")
        }
        client.connect(apiKey: apiKey, sourceLang: sourceLang, targetLang: targetLang)
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private func loadSharedSettingsFile() -> [String: Any] {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) else {
            return [:]
        }

        let fileURL = containerURL.appendingPathComponent("transifyr_shared_settings.json")
        guard let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    override func broadcastFinished() {
        client.disconnect()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .audioApp else { return }
        guard let pcm = converter.convert(sampleBuffer), !pcm.isEmpty else { return }
        client.sendAudio(pcm)
    }
}

private final class BroadcastSonioxClient {
    private var socket: URLSessionWebSocketTask?
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    private var pendingAudio: [Data] = []
    private var configSent = false
    private var configPayload: String = ""
    var onTranslation: ((String, String) -> Void)?

    func connect(apiKey: String, sourceLang: String, targetLang: String) {
        let url = URL(string: "wss://stt-rt.soniox.com/transcribe-websocket")!
        socket = session.webSocketTask(with: url)

        let sourceCode = sourceLang == "auto" ? nil : sourceLang
        var payload: [String: Any] = [
            "api_key": apiKey,
            "model": "stt-rt-v4",
            "audio_format": "pcm_s16le",
            "sample_rate": 16000,
            "num_channels": 1,
            "enable_endpoint_detection": true,
            "enable_language_identification": sourceCode == nil,
            "max_endpoint_delay_ms": 160,
            "translation": [
                "type": "one_way",
                "target_language": targetLang
            ]
        ]
        if let sourceCode {
            payload["language_hints"] = [sourceCode]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        configPayload = text

        socket?.resume()
        socket?.send(.string(text)) { [weak self] error in
            guard let self else { return }
            if error == nil {
                self.configSent = true
                for chunk in self.pendingAudio {
                    self.socket?.send(.data(chunk)) { _ in }
                }
                self.pendingAudio.removeAll()
            }
        }
        receiveLoop()
    }

    func sendAudio(_ data: Data) {
        guard let socket, socket.state == .running else { return }
        if configSent {
            socket.send(.data(data)) { _ in }
        } else {
            if pendingAudio.count < 50 {
                pendingAudio.append(data)
            }
        }
    }

    func disconnect() {
        configSent = false
        pendingAudio.removeAll()
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
    }

    private func receiveLoop() {
        socket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    self.handleResponse(text)
                }
                self.receiveLoop()
            case .failure:
                break
            }
        }
    }

    private func handleResponse(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if let errMsg = json["error"] as? String ?? json["error_message"] as? String {
            _ = errMsg
            return
        }

        guard let tokens = json["tokens"] as? [[String: Any]], !tokens.isEmpty else { return }

        var committedOriginal = ""
        var provisionalOriginal = ""
        var committedTranslation = ""
        var provisionalTranslation = ""
        var shouldEndSegment = false

        for token in tokens {
            if token["text"] as? String == "<end>" {
                shouldEndSegment = true
                continue
            }
            guard let tokenText = token["text"] as? String, !tokenText.isEmpty else { continue }

            let isTranslation = token["translation_status"] as? String == "translation"
            let isStable = isCommitted(token)

            if isTranslation {
                if isStable { committedTranslation += tokenText }
                else { provisionalTranslation += tokenText }
            } else {
                if isStable { committedOriginal += tokenText }
                else { provisionalOriginal += tokenText }
            }
        }

        let cleanOriginal = trimSubtitleBuffer(committedOriginal + provisionalOriginal)
        let cleanTranslation = trimSubtitleBuffer(committedTranslation + provisionalTranslation)

        if !cleanTranslation.isEmpty || !cleanOriginal.isEmpty {
            onTranslation?(cleanOriginal, cleanTranslation)
        }

        if shouldEndSegment {
            onTranslation?("", "")
        }
    }

    private func isCommitted(_ token: [String: Any]) -> Bool {
        (token["is_final"] as? Bool ?? false)
            || (token["final"] as? Bool ?? false)
            || (token["is_stable"] as? Bool ?? false)
            || (token["stable"] as? Bool ?? false)
    }

    private func trimSubtitleBuffer(_ text: String, maxChars: Int = 140) -> String {
        let normalized = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > maxChars else { return normalized }
        return String(normalized.suffix(maxChars)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private final class BroadcastPCMConverter {
    private var converter: AVAudioConverter?
    private let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!

    func convert(_ sampleBuffer: CMSampleBuffer) -> Data? {
        guard let inputBuffer = makePCMBuffer(from: sampleBuffer) else { return nil }

        if converter == nil || converter?.inputFormat != inputBuffer.format {
            converter = AVAudioConverter(from: inputBuffer.format, to: outputFormat)
        }
        guard let converter else { return nil }

        let ratio = outputFormat.sampleRate / inputBuffer.format.sampleRate
        let frameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio) + 32
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCapacity) else { return nil }

        var didProvideData = false
        let inputBlock: AVAudioConverterInputBlock = { _, status in
            if didProvideData {
                status.pointee = .noDataNow
                return nil
            }
            didProvideData = true
            status.pointee = .haveData
            return inputBuffer
        }

        var error: NSError?
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        guard error == nil, let channelData = outputBuffer.int16ChannelData else { return nil }
        return Data(bytes: channelData[0], count: Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size)
    }

    private func makePCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }

        let stream = streamDescription.pointee
        guard let format = AVAudioFormat(streamDescription: streamDescription) else { return nil }
        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }

        var blockBuffer: CMBlockBuffer?
        var audioBufferList = AudioBufferList()
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else { return nil }

        pcmBuffer.frameLength = frameCount
        let bytesPerFrame = Int(stream.mBytesPerFrame) > 1 ? Int(stream.mBytesPerFrame) : 1
        let byteCount = Int(frameCount) * bytesPerFrame

        if stream.mFormatFlags & kAudioFormatFlagIsFloat != 0, let floatChannelData = pcmBuffer.floatChannelData {
            let source = audioBufferList.mBuffers.mData!.assumingMemoryBound(to: Float.self)
            let count = Int(frameCount) < byteCount / MemoryLayout<Float>.size ? Int(frameCount) : byteCount / MemoryLayout<Float>.size
            floatChannelData[0].assign(from: source, count: count)
        } else if let int16ChannelData = pcmBuffer.int16ChannelData {
            let source = audioBufferList.mBuffers.mData!.assumingMemoryBound(to: Int16.self)
            let count = Int(frameCount) < byteCount / MemoryLayout<Int16>.size ? Int(frameCount) : byteCount / MemoryLayout<Int16>.size
            int16ChannelData[0].assign(from: source, count: count)
        } else {
            return nil
        }

        return pcmBuffer
    }
}
