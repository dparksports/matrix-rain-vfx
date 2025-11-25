import SwiftUI
import AppKit

@main
struct MatrixApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register font
        if let url = Bundle.module.url(forResource: "Matrix-Code", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        
        let contentView = MatrixView()
            .edgesIgnoringSafeArea(.all)

        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        // User requested to shorten by 1/3 again, so (1/3) * (2/3) = 2/9 of screen width
        let windowWidth = (screenRect.width / 13.0)
        let windowHeight = screenRect.height
        
        window = FloatingWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.setFrameOrigin(.zero)
        window.setFrameAutosaveName("MatrixWindow")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = true
        window.level = .floating
        window.ignoresMouseEvents = false // Set to true if you want click-through
        
        // Make it movable by background
        window.isMovableByWindowBackground = true
    }
}

class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
}
