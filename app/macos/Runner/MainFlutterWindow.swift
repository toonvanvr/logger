import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Default window size
    self.setContentSize(NSSize(width: 1280, height: 720))
    self.center()

    // Transparent title bar — Flutter content extends underneath
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true
    self.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerWindowChannel(controller: flutterViewController)
    registerUriChannel(controller: flutterViewController)

    super.awakeFromNib()
  }

  // MARK: - Window MethodChannel (com.logger/window)

  private func registerWindowChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.logger/window",
      binaryMessenger: controller.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let window = self else {
        result(FlutterError(code: "NO_WINDOW", message: "Window deallocated", details: nil))
        return
      }

      switch call.method {
      case "setAlwaysOnTop":
        guard let value = call.arguments as? Bool else {
          result(FlutterError(code: "BAD_ARGS", message: "Expected Bool", details: nil))
          return
        }
        window.level = value ? .floating : .normal
        result(nil)

      case "minimize":
        window.miniaturize(nil)
        result(nil)

      case "maximize":
        window.zoom(nil)
        result(nil)

      case "close":
        window.close()
        result(nil)

      case "isMaximized":
        result(window.isZoomed)

      case "setDecorated":
        guard let value = call.arguments as? Bool else {
          result(FlutterError(code: "BAD_ARGS", message: "Expected Bool", details: nil))
          return
        }
        if value {
          window.styleMask.insert(.titled)
          window.titleVisibility = .hidden
          window.titlebarAppearsTransparent = true
          window.styleMask.insert(.fullSizeContentView)
        } else {
          window.styleMask.remove(.titled)
        }
        window.isMovableByWindowBackground = true
        result(nil)

      case "startDrag":
        window.isMovableByWindowBackground = true
        if let event = NSApp.currentEvent {
          window.performDrag(with: event)
        }
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - URI MethodChannel (com.logger/uri)

  private func registerUriChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.logger/uri",
      binaryMessenger: controller.engine.binaryMessenger
    )

    // Forward logger:// URIs from command line args
    let args = ProcessInfo.processInfo.arguments
    for arg in args {
      if arg.hasPrefix("logger://") {
        channel.invokeMethod("handleUri", arguments: arg)
        break
      }
    }
  }
}
