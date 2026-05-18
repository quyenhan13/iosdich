import AVFoundation

final class AudioSessionManager {
    static func configureForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        Logger.log("Đã cấu hình thành công AVAudioSession cho việc thu âm.")
    }

    static func deactivate() throws {
        try AVAudioSession.sharedInstance().setActive(false)
        Logger.log("Đã tắt AVAudioSession.")
    }
}
