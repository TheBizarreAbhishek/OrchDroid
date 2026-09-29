import Cocoa
import WebKit
import Foundation

// ============================================================================
// OrchDroid Native macOS Host Application
// Standalone Native App embedding OrchDroid Gaming Engine & Manager
// ============================================================================

class HostAppScriptHandler: NSObject, WKScriptMessageHandler {
    weak var appDelegate: AppDelegate?
    
    init(appDelegate: AppDelegate?) {
        self.appDelegate = appDelegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let action = dict["action"] as? String else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let delegate = self?.appDelegate else { return }
            
            if action == "resize",
               let w = dict["width"] as? CGFloat,
               let h = dict["height"] as? CGFloat {
                if let win = delegate.mainWindow {
                    var frame = win.frame
                    let deltaY = h - frame.size.height
                    frame.origin.y -= deltaY // Keep top-left stationary
                    frame.size.width = w
                    frame.size.height = h
                    win.setFrame(frame, display: true, animate: true)
                }
            } else if action == "openSettings" {
                let instId = (dict["instanceId"] as? String) ?? "default"
                let instName = (dict["instanceName"] as? String) ?? "Android Device"
                delegate.openSettingsWindow(instanceId: instId, instanceName: instName)
            } else if action == "updateSettingsTitle",
                      let title = dict["title"] as? String {
                delegate.settingsWindow?.title = title
            } else if action == "closeSettings" {
                delegate.settingsWindow?.close()
            } else if action == "close" {
                NSApp.terminate(nil)
            } else if action == "minimize" {
                delegate.mainWindow?.miniaturize(nil)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {
    var mainWindow: NSWindow!
    var mainWebView: WKWebView!
    var settingsWindow: NSWindow?
    var settingsWebView: WKWebView?
    var scriptHandler: HostAppScriptHandler!
    var serverProcess: Process?
    let serverURL = URL(string: "http://127.0.0.1:8088")!
    let serverScriptPath = "/Volumes/LinuxFS/OrchDroid/server.py"

    func applicationDidFinishLaunching(_ notification: Notification) {
        startServerIfNeeded()

        // Set dock icon from host_icon.png
        let iconPath = "/Volumes/LinuxFS/OrchDroid/dist/host_icon.png"
        if let iconImg = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = iconImg
        }

        self.scriptHandler = HostAppScriptHandler(appDelegate: self)

        // 1. Create Main Manager Window (OrchDroid Pro Studio - spacious 640px)
        let initialWidth: CGFloat = 640
        let initialHeight: CGFloat = 220
        let win = NSWindow(
            contentRect: NSRect(x: 200, y: 400, width: initialWidth, height: initialHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "OrchDroid Pro"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.appearance = NSAppearance(named: .darkAqua)
        win.backgroundColor = NSColor(calibratedRed: 0.13, green: 0.135, blue: 0.15, alpha: 1.0)
        win.isMovableByWindowBackground = true

        let webConfig = WKWebViewConfiguration()
        webConfig.websiteDataStore = .nonPersistent()
        webConfig.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        let contentController = WKUserContentController()
        contentController.add(scriptHandler, name: "hostApp")
        webConfig.userContentController = contentController

        mainWebView = WKWebView(frame: win.contentView!.bounds, configuration: webConfig)
        mainWebView.autoresizingMask = [.width, .height]
        mainWebView.navigationDelegate = self
        mainWebView.uiDelegate = self
        mainWebView.setValue(false, forKey: "drawsBackground")
        
        win.contentView?.addSubview(mainWebView)
        self.mainWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.loadApp()
        }
    }

    func openSettingsWindow(instanceId: String, instanceName: String) {
        if let win = settingsWindow {
            win.title = "OrchDroid Settings - \(instanceName)"
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            if let webView = settingsWebView,
               let url = URL(string: "http://127.0.0.1:8088/settings.html?id=\(instanceId)") {
                webView.load(URLRequest(url: url))
            }
            return
        }

        let winWidth: CGFloat = 620
        let winHeight: CGFloat = 550

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: winWidth, height: winHeight),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "OrchDroid Settings - \(instanceName)"
        win.appearance = NSAppearance(named: .darkAqua)
        win.backgroundColor = NSColor(calibratedRed: 0.13, green: 0.135, blue: 0.15, alpha: 1.0)
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.center()

        let webConfig = WKWebViewConfiguration()
        webConfig.websiteDataStore = .nonPersistent()
        webConfig.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        let contentController = WKUserContentController()
        contentController.add(scriptHandler, name: "hostApp")
        webConfig.userContentController = contentController

        let webView = WKWebView(frame: win.contentView!.bounds, configuration: webConfig)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")

        if let url = URL(string: "http://127.0.0.1:8088/settings.html?id=\(instanceId)") {
            webView.load(URLRequest(url: url))
        }

        win.contentView?.addSubview(webView)
        self.settingsWindow = win
        self.settingsWebView = webView

        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: win, queue: .main) { [weak self] _ in
            self?.settingsWindow = nil
            self?.settingsWebView = nil
        }

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func startServerIfNeeded() {
        var request = URLRequest(url: serverURL)
        request.timeoutInterval = 0.4
        let sem = DispatchSemaphore(value: 0)
        var serverUp = false
        
        let task = URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                serverUp = true
            }
            sem.signal()
        }
        task.resume()
        _ = sem.wait(timeout: .now() + 0.4)

        if !serverUp {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            proc.arguments = [serverScriptPath]
            proc.currentDirectoryURL = URL(fileURLWithPath: "/Volumes/LinuxFS/OrchDroid")
            try? proc.run()
            self.serverProcess = proc
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func loadApp() {
        mainWebView.load(URLRequest(url: serverURL))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.loadApp()
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "OrchDroid Pro"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "OrchDroid Pro"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        serverProcess?.terminate()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
