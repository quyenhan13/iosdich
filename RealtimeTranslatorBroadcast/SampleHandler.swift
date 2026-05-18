import AVFoundation
import CoreMedia
import ReplayKit

final class SampleHandler: RPBroadcastSampleHandler {
    private let client = BroadcastSonioxClient()
    private let converter = BroadcastPCMConverter()
    private let defaults = UserDefaults(suiteName: "group.com.vteen.RealtimeTranslator")

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        let apiKey = defaults?.string(forKey: "soniox_api_key_fallback") ?? ""
        let sourceLang = defaults?.string(forKey: "source_language") ?? "auto"
        let targetLang = defaults?.string(forKey: "target_language") ?? "vi"

        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            finishBroadcastWithError(NSError(domain: "TransifyrBroadcast", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Chưa có Soniox API Key. Mở app Transifyr và lưu key trước."
            ]))
            return
        }

        client.onTranslation = { [weak self] text in
            self?.defaults?.set(text, forKey: "broadcast_current_translation")
            self?.defaults?.set(Date().timeIntervalSince1970, forKey: "broadcast_current_translation_at")
        }
        client.connect(apiKey: apiKey, sourceLang: sourceLang, targetLang: targetLang)
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
    private let encoder = JSONEncoder()
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    private var connected = false
    private var confirmedTranslation = ""
    var onTranslation: ((String) -> Void)?

    func connect(apiKey: String, sourceLang: String, targetLang: String) {
        let url = URL(string: "wss://stt-rt.soniox.com/transcribe-websocket")!
        socket = session.webSocketTask(with: url)
        socket?.resume()

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

        socket?.send(.string(text)) { [weak self] error in
            self?.connected = error == nil
        }
        receiveLoop()
    }

    func sendAudio(_ data: Data) {
        guard connected else { return }
        socket?.send(.data(data)) { _ in }
    }

    func disconnect() {
        connected = false
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
    }

    private func receiveLoop() {
        socket?.receive { [weak self] result in
            guard let self else { return }
            if case .success(let message) = result {
                if case .string(let text) = message {
                    self.handleResponse(text)
                }
                self.receiveLoop()
            } else {
                self.connected = false
            }
        }
    }

    private func handleResponse(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [[String: Any]] else { return }

        var committedTranslation = ""
        var provisionalTranslation = ""

        for token in tokens {
            guard token["translation_status"] as? String == "translation",
                  let text = token["text"] as? String,
                  !text.isEmpty,
                  text != "<end>" else { continue }

            if isCommitted(token) {
                committedTranslation += text
            } else {
                provisionalTranslation += text
            }
        }

        if !committedTranslation.isEmpty {
            confirmedTranslation = appendUniqueText(confirmedTranslation, committedTranslation)
        }

        let clean = trimSubtitleBuffer(confirmedTranslation + provisionalTranslation)
        if !clean.isEmpty {
            onTranslation?(clean)
        }

        if confirmedTranslation.count > 1800 {
            confirmedTranslation = String(confirmedTranslation.suffix(1200))
        }
    }

    private func isCommitted(_ token: [String: Any]) -> Bool {
        (token["is_final"] as? Bool ?? false)
            || (token["final"] as? Bool ?? false)
            || (token["is_stable"] as? Bool ?? false)
            || (token["stable"] as? Bool ?? false)
    }

    private func appendUniqueText(_ base: String, _ addition: String) -> String {
        let cleanAddition = addition.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard !cleanAddition.isEmpty else { return base }
        if base.hasSuffix(cleanAddition) {
            return base
        }
        return base + cleanAddition
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
        let bytesPerFrame = max(Int(stream.mBytesPerFrame), 1)
        let byteCount = Int(frameCount) * bytesPerFrame

        if stream.mFormatFlags & kAudioFormatFlagIsFloat != 0, let floatChannelData = pcmBuffer.floatChannelData {
            let source = audioBufferList.mBuffers.mData!.assumingMemoryBound(to: Float.self)
            floatChannelData[0].assign(from: source, count: min(Int(frameCount), byteCount / MemoryLayout<Float>.size))
        } else if let int16ChannelData = pcmBuffer.int16ChannelData {
            let source = audioBufferList.mBuffers.mData!.assumingMemoryBound(to: Int16.self)
            int16ChannelData[0].assign(from: source, count: min(Int(frameCount), byteCount / MemoryLayout<Int16>.size))
        } else {
            return nil
        }

        return pcmBuffer
    }
}
