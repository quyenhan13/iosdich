import Combine
import ObjectiveC.runtime
import UIKit

@_silgen_name("objc_msgSend")
private func objcMsgSend0(_ target: AnyObject, _ selector: Selector) -> Unmanaged<AnyObject>?

@_silgen_name("objc_msgSend")
private func objcMsgSend1(_ target: AnyObject, _ selector: Selector, _ arg1: AnyObject?) -> Unmanaged<AnyObject>?

@_silgen_name("objc_msgSend")
private func objcMsgSend2(_ target: AnyObject, _ selector: Selector, _ arg1: AnyObject?, _ arg2: AnyObject?) -> Unmanaged<AnyObject>?

@_silgen_name("objc_msgSend")
private func objcMsgSendIntObject(_ target: AnyObject, _ selector: Selector, _ arg1: Int32, _ arg2: AnyObject?) -> Unmanaged<AnyObject>?

final class SystemFloatingSceneManager: ObservableObject {
    static let shared = SystemFloatingSceneManager()

    @Published private(set) var isRunning = false

    private var window: UIWindow?
    private var controller: SystemFloatingSubtitleViewController?
    private var frontBoardBinder: NSObject?
    private var frontBoardScene: NSObject?
    private var lastOriginal = ""
    private var lastTranslation = ""
    private var lastFailureReason = ""
    private let enableKey = "enable_system_floating_scene"

    private init() {}

    var isSupported: Bool {
        systemSceneEnabled
            && NSClassFromString("UIRootWindowScenePresentationBinder") != nil
            && NSClassFromString("FBSceneManager") != nil
            && NSClassFromString("FBSMutableSceneDefinition") != nil
    }

    private var systemSceneEnabled: Bool {
        UserDefaults.standard.object(forKey: enableKey) as? Bool ?? true
    }

    var diagnosticSummary: String {
        [
            "UIRootWindowScenePresentationBinder": NSClassFromString("UIRootWindowScenePresentationBinder") != nil,
            "FBSceneManager": NSClassFromString("FBSceneManager") != nil,
            "FBSMutableSceneDefinition": NSClassFromString("FBSMutableSceneDefinition") != nil,
            "FBSSceneClientIdentity": NSClassFromString("FBSSceneClientIdentity") != nil,
            "UIStatusBarServer": NSClassFromString("UIStatusBarServer") != nil,
            "lastFailure": !lastFailureReason.isEmpty
        ]
        .map { "\($0.key)=\($0.value ? "yes" : "no")" }
        .sorted()
        .joined(separator: ", ")
    }

    @discardableResult
    func start() -> Bool {
        guard window == nil else {
            isRunning = true
            return true
        }

        guard isSupported else {
            lastFailureReason = "System floating scene is disabled or unavailable."
            Logger.log("System floating scene unavailable: \(diagnosticSummary)")
            return false
        }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) else {
            lastFailureReason = "No active UIWindowScene."
            Logger.log("System floating scene unavailable: \(lastFailureReason)")
            return false
        }

        _ = createFrontBoardScene(from: scene)

        let controller = SystemFloatingSubtitleViewController()
        let overlayWindow = makeRootSceneWindow(scene: scene)
        overlayWindow.windowLevel = UIWindow.Level.statusBar + 10000
        overlayWindow.backgroundColor = .clear
        overlayWindow.rootViewController = controller
        overlayWindow.isHidden = false
        overlayWindow.makeKeyAndVisible()

        controller.loadViewIfNeeded()
        controller.update(original: lastOriginal, translation: lastTranslation)

        self.controller = controller
        self.window = overlayWindow
        isRunning = true
        Logger.log("System floating scene started: \(diagnosticSummary)")
        return true
    }

    func stop() {
        window?.isHidden = true
        window = nil
        controller = nil
        destroyFrontBoardScene()
        isRunning = false
    }

    func update(text: String, translation: String) {
        lastOriginal = text
        lastTranslation = translation
        controller?.update(original: text, translation: translation)
    }

    private func makeRootSceneWindow(scene: UIWindowScene) -> UIWindow {
        return PassthroughSystemWindow(windowScene: scene)
    }

    private func createFrontBoardScene(from windowScene: UIWindowScene) -> Bool {
        guard frontBoardBinder == nil, frontBoardScene == nil else { return true }
        guard
            let binderClass = NSClassFromString("UIRootWindowScenePresentationBinder") as? NSObject.Type,
            let definitionClass = NSClassFromString("FBSMutableSceneDefinition") as? NSObject.Type,
            let sceneIdentityClass = NSClassFromString("FBSSceneIdentity") as? NSObject.Type,
            let clientIdentityClass = NSClassFromString("FBSSceneClientIdentity") as? NSObject.Type,
            let specificationClass = NSClassFromString("UIApplicationSceneSpecification") as? NSObject.Type,
            let parametersClass = NSClassFromString("FBSMutableSceneParameters") as? NSObject.Type,
            let sceneManagerClass = NSClassFromString("FBSceneManager") as? NSObject.Type
        else {
            lastFailureReason = "FrontBoard classes missing."
            Logger.log("FrontBoard local scene unavailable: \(diagnosticSummary)")
            return false
        }

        let displayConfiguration = windowScene.value(forKeyPath: "_effectiveSettings.displayConfiguration")
        guard let allocatedBinder = binderClass.performClassObject(selector: "alloc"),
              let binder = objcMsgSendIntObject(
                allocatedBinder,
                NSSelectorFromString("initWithPriority:displayConfiguration:"),
                0,
                displayConfiguration as AnyObject?
              )?.takeUnretainedValue() as? NSObject else {
            lastFailureReason = "Could not create presentation binder."
            Logger.log("FrontBoard binder unavailable: \(diagnosticSummary)")
            return false
        }

        guard
            let definition = definitionClass.performClassObject(selector: "definition"),
            let identity = sceneIdentityClass.performClassObject(
                selector: "identityForIdentifier:",
                Bundle.main.bundleIdentifier ?? "com.vteen.RealtimeTranslator"
            ),
            let clientIdentity = clientIdentityClass.performClassObject(selector: "localIdentity"),
            let specification = specificationClass.performClassObject(selector: "specification"),
            let parameters = parametersClass.performClassObject(selector: "parametersForSpecification:", specification),
            let sceneManager = sceneManagerClass.performClassObject(selector: "sharedInstance")
        else {
            lastFailureReason = "Could not create FrontBoard definition."
            return false
        }

        definition.setValue(identity, forKey: "identity")
        definition.setValue(clientIdentity, forKey: "clientIdentity")
        definition.setValue(specification, forKey: "specification")

        if let settings = (windowScene.value(forKey: "_effectiveSettings") as? NSObject)?.mutableCopy() as? NSObject {
            settings.setValue(NSNumber(value: 0), forKey: "deactivationReasons")
            settings.setValue(NSNumber(value: true), forKey: "foreground")
            settings.setValue(NSNumber(value: 0), forKey: "interruptionPolicy")
            parameters.setValue(settings, forKey: "settings")
        }
        parameters.setValue(windowScene.value(forKey: "_effectiveUIClientSettings"), forKey: "clientSettings")

        guard let createdScene = sceneManager.performObject(
            selector: "createSceneWithDefinition:initialParameters:",
            definition,
            parameters
        ) else {
            lastFailureReason = "FBSceneManager createScene failed."
            return false
        }

        _ = binder.performObject(selector: "addScene:", createdScene)
        frontBoardBinder = binder
        frontBoardScene = createdScene
        Logger.log("FrontBoard local scene created: \(diagnosticSummary)")
        return true
    }

    private func destroyFrontBoardScene() {
        guard let scene = frontBoardScene,
              let sceneManagerClass = NSClassFromString("FBSceneManager") as? NSObject.Type,
              let sceneManager = sceneManagerClass.performClassObject(selector: "sharedInstance") else {
            frontBoardScene = nil
            frontBoardBinder = nil
            return
        }

        _ = sceneManager.performObject(selector: "destroyScene:withTransitionContext:", scene, NSNull())
        frontBoardScene = nil
        frontBoardBinder = nil
    }
}

private extension NSObject {
    static func performClassObject(selector: String, _ arg1: Any? = nil, _ arg2: Any? = nil) -> NSObject? {
        (self as AnyObject).performObject(selector: selector, arg1, arg2)
    }
}

private extension AnyObject {
    func performObject(selector: String, _ arg1: Any? = nil, _ arg2: Any? = nil) -> NSObject? {
        let sel = NSSelectorFromString(selector)
        guard self.responds(to: sel) else { return nil }
        if let arg2 {
            let secondArg: AnyObject? = (arg2 as? NSNull) == nil ? arg2 as AnyObject : nil
            return objcMsgSend2(self, sel, arg1 as AnyObject?, secondArg)?.takeUnretainedValue() as? NSObject
        }
        if let arg1 {
            return objcMsgSend1(self, sel, arg1 as AnyObject?)?.takeUnretainedValue() as? NSObject
        }
        return objcMsgSend0(self, sel)?.takeUnretainedValue() as? NSObject
    }
}

private final class PassthroughSystemWindow: UIWindow {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let root = rootViewController?.view,
              let hitView = root.hitTest(point, with: event) else { return false }
        return hitView !== root
    }
}

private final class SystemFloatingSubtitleViewController: UIViewController {
    private let container = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let label = UILabel()
    private var hideTimer: Timer?
    private var panStartCenter = CGPoint.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        container.layer.cornerRadius = 18
        container.layer.cornerCurve = .continuous
        container.clipsToBounds = true
        container.alpha = 0
        container.isUserInteractionEnabled = true
        view.addSubview(container)

        label.textColor = .white
        label.font = .systemFont(ofSize: 19, weight: .heavy)
        label.numberOfLines = 2
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.72
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.9
        label.layer.shadowRadius = 4
        label.layer.shadowOffset = CGSize(width: 0, height: 2)
        container.contentView.addSubview(label)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        container.addGestureRecognizer(pan)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if container.frame == .zero {
            let width = min(view.bounds.width - 36, 430)
            container.frame = CGRect(
                x: (view.bounds.width - width) / 2,
                y: view.bounds.height - view.safeAreaInsets.bottom - 128,
                width: width,
                height: 72
            )
        }
        label.frame = container.bounds.insetBy(dx: 18, dy: 10)
    }

    func update(original: String, translation: String) {
        let text = translation

        label.text = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        hideTimer?.invalidate()
        guard label.text?.isEmpty == false else {
            setVisible(false)
            return
        }

        setVisible(true)
        hideTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
            self?.setVisible(false)
        }
    }

    private func setVisible(_ visible: Bool) {
        UIView.animate(withDuration: 0.2) {
            self.container.alpha = visible ? 1 : 0
        }
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            panStartCenter = container.center
        case .changed:
            let translation = recognizer.translation(in: view)
            container.center = CGPoint(x: panStartCenter.x + translation.x, y: panStartCenter.y + translation.y)
        case .ended, .cancelled:
            clampToScreen()
        default:
            break
        }
    }

    private func clampToScreen() {
        var frame = container.frame
        frame.origin.x = min(max(frame.origin.x, 12), view.bounds.width - frame.width - 12)
        frame.origin.y = min(max(frame.origin.y, view.safeAreaInsets.top + 12), view.bounds.height - view.safeAreaInsets.bottom - frame.height - 12)

        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.84, initialSpringVelocity: 0.3) {
            self.container.frame = frame
        }
    }
}
