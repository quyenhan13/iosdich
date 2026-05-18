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
    private var lastRenderedText = ""
    private var lastRenderSize = CGSize.zero
    private var scrollOffset: CGFloat = 0
    private var hideTextAt: Date?
    private var frameIndex: Int64 = 0
    private let frameRate: Int32 = 24

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
        hideTextAt = currentText.isEmpty ? nil : Date().addingTimeInterval(6)
        enqueueFrame(force: true)
    }

    private func startFrameTimer() {
        frameTimer?.invalidate()
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(frameRate), repeats: true) { [weak self] _ in
            self?.enqueueFrame(force: false)
        }
        frameTimer?.tolerance = 0.01
    }

    private func enqueueFrame(force: Bool) {
        guard force || pipController?.isPictureInPictureActive == true else { return }
        if let hideTextAt, Date() >= hideTextAt {
            currentText = ""
            self.hideTextAt = nil
        }
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
        let renderSize = currentRenderSize()
        if renderSize != lastRenderSize {
            lastRenderSize = renderSize
            scrollOffset = 0
            lastRenderedText = ""
        }

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

        let displayText = compactSubtitle(text)
        guard !displayText.isEmpty else {
            UIGraphicsPopContext()
            return pixelBuffer
        }

        let tickerRect = CGRect(x: 10, y: 10, width: renderSize.width - 20, height: renderSize.height - 20)
        UIColor.black.withAlphaComponent(0.82).setFill()
        UIBezierPath(roundedRect: tickerRect, cornerRadius: tickerRect.height / 2).fill()

        UIColor.white.withAlphaComponent(0.08).setStroke()
        let border = UIBezierPath(roundedRect: tickerRect.insetBy(dx: 1, dy: 1), cornerRadius: (tickerRect.height - 2) / 2)
        border.lineWidth = 1
        border.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byClipping

        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: renderSize.width > 700 ? 38 : 30, weight: .heavy),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph,
            .strokeColor: UIColor.black,
            .strokeWidth: -4
        ]

        let nsText = NSString(string: displayText)
        let textSize = nsText.size(withAttributes: textAttrs)
        let contentRect = tickerRect.insetBy(dx: 26, dy: 10)
        let y = contentRect.midY - textSize.height / 2

        if displayText != lastRenderedText {
            lastRenderedText = displayText
            scrollOffset = contentRect.width
        }

        let x: CGFloat
        if textSize.width > contentRect.width {
            scrollOffset -= 2.8
            if scrollOffset < -textSize.width - 80 {
                scrollOffset = contentRect.width
            }
            x = contentRect.minX + scrollOffset
        } else {
            x = contentRect.midX - textSize.width / 2
        }

        context.saveGState()
        context.clip(to: contentRect)
        nsText.draw(at: CGPoint(x: x, y: y), withAttributes: textAttrs)
        context.restoreGState()
        UIGraphicsPopContext()

        return pixelBuffer
    }

    private func compactSubtitle(_ text: String, limit: Int = 220) -> String {
        let normalized = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        return String(normalized.suffix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currentRenderSize() -> CGSize {
        let screenBounds = UIScreen.main.bounds
        let isLandscape = screenBounds.width > screenBounds.height
        let scale = UIScreen.main.scale
        let screenWidth = max(screenBounds.width, screenBounds.height)
        let portraitWidth = min(max(min(screenBounds.width, screenBounds.height) * scale * 0.72, 300), 420)
        let landscapeWidth = min(max(screenWidth * scale * 0.54, 520), 760)
        return CGSize(width: isLandscape ? landscapeWidth : portraitWidth, height: isLandscape ? 78 : 68)
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
