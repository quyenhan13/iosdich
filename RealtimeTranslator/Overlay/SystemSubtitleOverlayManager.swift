import AVFoundation
import AVKit
import CoreMedia
import UIKit

final class SystemSubtitleOverlayManager: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var isSupported = AVPictureInPictureController.isPictureInPictureSupported()

    private let displayLayer = AVSampleBufferDisplayLayer()
    private var pipController: AVPictureInPictureController?
    private var frameTimer: Timer?
    private var currentText = ""
    private var frameIndex: Int64 = 0
    private let frameRate: Int32 = 2
    private let renderSize = CGSize(width: 960, height: 360)

    override init() {
        super.init()
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = UIColor.clear.cgColor

        if #available(iOS 15.0, *) {
            let source = AVPictureInPictureController.ContentSource(
                sampleBufferDisplayLayer: displayLayer,
                playbackDelegate: self
            )
            let controller = AVPictureInPictureController(contentSource: source)
            controller.canStartPictureInPictureAutomaticallyFromInline = true
            controller.delegate = self
            pipController = controller
        }
    }

    func start() {
        guard isSupported, pipController?.isPictureInPictureActive != true else { return }
        do {
            try AudioSessionManager.configureForPlaybackOverlay()
            enqueueFrame(force: true)
            startFrameTimer()
            pipController?.startPictureInPicture()
        } catch {
            Logger.log("Không thể bật phụ đề nổi: \(error.localizedDescription)", level: .error)
        }
    }

    func stop() {
        frameTimer?.invalidate()
        frameTimer = nil
        pipController?.stopPictureInPicture()
        DispatchQueue.main.async {
            self.isRunning = false
        }
    }

    func update(text: String, translation: String) {
        let next = translation.isEmpty ? text : translation
        currentText = next.trimmingCharacters(in: .whitespacesAndNewlines)
        enqueueFrame(force: true)
    }

    private func startFrameTimer() {
        frameTimer?.invalidate()
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(frameRate), repeats: true) { [weak self] _ in
            self?.enqueueFrame(force: false)
        }
        frameTimer?.tolerance = 0.08
    }

    private func enqueueFrame(force: Bool) {
        guard force || pipController?.isPictureInPictureActive == true else { return }
        guard let buffer = makeSampleBuffer(text: currentText) else { return }
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(buffer)
    }

    private func makeSampleBuffer(text: String) -> CMSampleBuffer? {
        guard let pixelBuffer = makePixelBuffer(text: text) else { return nil }

        var formatDescription: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard let formatDescription else { return nil }

        let pts = CMTime(value: frameIndex, timescale: frameRate)
        frameIndex += 1
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: frameRate),
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        if let sampleBuffer,
           let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) as? [CFMutableDictionary] {
            for item in attachments {
                CFDictionarySetValue(
                    item,
                    Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                    Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
                )
            }
        }
        return sampleBuffer
    }

    private func makePixelBuffer(text: String) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]

        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(renderSize.width),
            Int(renderSize.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        guard let context = CGContext(
            data: baseAddress,
            width: Int(renderSize.width),
            height: Int(renderSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        UIGraphicsPushContext(context)
        UIColor.clear.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: renderSize)).fill()

        let bubbleRect = CGRect(x: 42, y: 118, width: renderSize.width - 84, height: 156)
        UIColor.black.withAlphaComponent(text.isEmpty ? 0.28 : 0.68).setFill()
        UIBezierPath(roundedRect: bubbleRect, cornerRadius: 34).fill()

        let displayText = text.isEmpty ? "Transifyr đang nghe..." : text
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: text.isEmpty ? 34 : 42, weight: .bold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph,
            .strokeColor: UIColor.black.withAlphaComponent(0.65),
            .strokeWidth: -3
        ]

        NSString(string: displayText).draw(
            with: bubbleRect.insetBy(dx: 28, dy: 26),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: textAttrs,
            context: nil
        )
        UIGraphicsPopContext()

        return pixelBuffer
    }
}

extension SystemSubtitleOverlayManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isRunning = true
        }
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isRunning = false
        }
    }
}

extension SystemSubtitleOverlayManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {}

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: CMTime(value: 24 * 60 * 60, timescale: 1))
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        false
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
