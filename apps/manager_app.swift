import Cocoa
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var serverProcess: Process?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        // Start server daemon if not running
        ensureServerRunning()
        
        // Window sizing & styling - Modern Dark Glassmorphic Window
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 1440, height: 900)
        let winWidth: CGFloat = 1100
        let winHeight: CGFloat = 720
        let winX = screenRect.origin.x + (screenRect.width - winWidth) / 2
        let winY = screenRect.origin.y + (screenRect.height - winHeight) / 2
        let winRect = NSRect(x: winX, y: winY, width: winWidth, height: winHeight)
        
        window = NSWindow(
            contentRect: winRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "OrchDroid Pro - Android Virtualization Manager"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.09, alpha: 1.0)
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        
        // Load local dashboard
        if let url = URL(string: "http://127.0.0.1:8088") {
            webView.load(URLRequest(url: url))
        }
        
        window.contentView?.addSubview(webView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        setupMenu()
    }
    
    func ensureServerRunning() {
        // Check if port 8088 is responding
        guard let url = URL(string: "http://127.0.0.1:8088/api/instances") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0
        
        let sem = DispatchSemaphore(value: 0)
        var isUp = false
        URLSession.shared.dataTask(with: request) { _, resp, _ in
            if let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                isUp = true
            }
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + 1.0)
        
        if !isUp {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            proc.arguments = ["/Volumes/LinuxFS/OrchDroid/server.py"]
            proc.currentDirectoryURL = URL(fileURLWithPath: "/Volumes/LinuxFS/OrchDroid")
            try? proc.run()
            self.serverProcess = proc
            Thread.sleep(forTimeInterval: 1.0)
        }
    }
    
    func setupMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        appMenu.addItem(NSMenuItem(title: "About OrchDroid Pro", action: #selector(aboutApp), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Preferences...", action: nil, keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit OrchDroid", action: #selector(quitApp), keyEquivalent: "q"))
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc func aboutApp() {
        let alert = NSAlert()
        alert.messageText = "OrchDroid Pro v1.0.0"
        alert.informativeText = "High-Performance Native Android 14 Gaming Emulator for Apple Silicon.\nPowered by Metal Graphics & HVF Acceleration."
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.terminate(nil)
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
