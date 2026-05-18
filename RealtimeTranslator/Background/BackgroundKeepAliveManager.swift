import UIKit

final class BackgroundKeepAliveManager {
    static let shared = BackgroundKeepAliveManager()

    private var taskId: UIBackgroundTaskIdentifier = .invalid

    private init() {}

    func begin() {
        guard taskId == .invalid else { return }

        taskId = UIApplication.shared.beginBackgroundTask(withName: "RealtimeTranslatorAudio") { [weak self] in
            self?.end()
        }

        if taskId == .invalid {
            Logger.log("Không thể bắt đầu background task.", level: .error)
        } else {
            Logger.log("Đã bắt đầu background task cho realtime audio.")
        }
    }

    func end() {
        guard taskId != .invalid else { return }
        UIApplication.shared.endBackgroundTask(taskId)
        taskId = .invalid
        Logger.log("Đã kết thúc background task.")
    }
}
