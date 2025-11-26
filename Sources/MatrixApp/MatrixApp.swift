import SwiftUI
import AppKit

extension Notification.Name {
    static let tuckUnderMenu = Notification.Name("tuckUnderMenu")
    static let tuckUnderDock = Notification.Name("tuckUnderDock")
    static let tuckLeft = Notification.Name("tuckLeft")
    static let tuckRight = Notification.Name("tuckRight")
}

@main
struct MatrixApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register font
        if let url = Bundle.module.url(forResource: "Matrix-Code", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        
        let contentView = MatrixView()
            .edgesIgnoringSafeArea(.all)
        
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        // Default to 1/3 width (approx 5-6 columns depending on screen)
        // or start with 3 columns as per previous logic?
        // Let's stick to the previous logic for initial size: 2/9 of screen width
        let windowWidth = (screenRect.width / 13.0) 
        // User requested height = laptop height - menu bar height
        // visibleFrame.maxY is the bottom of the menu bar (top of usable area)
        let windowHeight = NSScreen.main?.visibleFrame.maxY ?? screenRect.height
        
        window = FloatingWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.delegate = self // Set delegate for logging
        window.setFrameOrigin(.zero)
        window.setFrameAutosaveName("MatrixWindow")
        window.contentView = NSHostingView(rootView: contentView)
        
        // Chamfered edges
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 15.0
        window.contentView?.layer?.borderWidth = 1.0 // Thinner chamfer
        window.contentView?.layer?.borderColor = NSColor(deviceWhite: 0.85, alpha: 1.0).cgColor
        window.contentView?.layer?.masksToBounds = true
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true) // Fix focus
        window.backgroundColor = .clear // Clear for chamfer
        window.isOpaque = false // False for chamfer
        window.hasShadow = true
        window.level = .floating
        window.ignoresMouseEvents = false
        
        // Make it movable by background
        window.isMovableByWindowBackground = true
        
        // Observers for UI buttons
        NotificationCenter.default.addObserver(forName: .tuckUnderMenu, object: nil, queue: .main) { _ in
            guard let screen = self.window.screen else { return }
            let screenFrame = screen.frame

            let newFrame = NSRect(x: 0, y: 898, width: 1470, height: 58)
            self.window.setFrame(newFrame, display: true, animate: true)
            self.window.level = NSWindow.Level(Int(CGWindowLevelForKey(.dockWindow)) - 1)            
        }
        
        NotificationCenter.default.addObserver(forName: .tuckUnderDock, object: nil, queue: .main) { _ in
            guard let screen = self.window.screen else { return }
            let screenFrame = screen.frame
            let visibleFrame = screen.visibleFrame
            
            let dockHeight = visibleFrame.minY - screenFrame.minY
            if dockHeight > 0 {
                let newFrame = NSRect(x: 0, y: screenFrame.minY, width: screenFrame.width, height: dockHeight)
                self.window.setFrame(newFrame, display: true)
                self.window.level = NSWindow.Level(Int(CGWindowLevelForKey(.dockWindow)) - 1)
            }
        }
        
        NotificationCenter.default.addObserver(forName: .tuckLeft, object: nil, queue: .main) { _ in
            guard let screen = self.window.screen else { return }
            let screenFrame = screen.frame
            
            // Simulate Left Dock
            let dockWidth: CGFloat = 80.0 // Fixed width for simulated dock
            let newFrame = NSRect(x: screenFrame.minX, y: screenFrame.minY, width: dockWidth, height: screenFrame.height)
            self.window.setFrame(newFrame, display: true)
            self.window.level = NSWindow.Level(Int(CGWindowLevelForKey(.dockWindow)) - 1)
        }
        
        NotificationCenter.default.addObserver(forName: .tuckRight, object: nil, queue: .main) { _ in
            guard let screen = self.window.screen else { return }
            let screenFrame = screen.frame
            
            // Simulate Right Dock
            let dockWidth: CGFloat = 80.0 // Fixed width for simulated dock
            let newFrame = NSRect(x: screenFrame.maxX - dockWidth, y: screenFrame.minY, width: dockWidth, height: screenFrame.height)
            self.window.setFrame(newFrame, display: true)
            self.window.level = NSWindow.Level(Int(CGWindowLevelForKey(.dockWindow)) - 1)
        }

        
        // Trigger tuck under dock on launch
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .tuckUnderDock, object: nil)
        }
    }

    func windowDidResize(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            print("Window Frame: \(window.frame)")
        }
    }
}

class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        guard let screen = self.screen else { return }
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        
        let cmdPressed = event.modifierFlags.contains(.command)
        
        if cmdPressed {
            switch event.specialKey {
            case .leftArrow:
                // Stick to left
                self.level = .floating // Reset level
                let newOrigin = NSPoint(x: screenFrame.minX, y: self.frame.minY)
                self.setFrameOrigin(newOrigin)
                return
            case .rightArrow:
                // Stick to right
                self.level = .floating // Reset level
                let newOrigin = NSPoint(x: screenFrame.maxX - self.frame.width, y: self.frame.minY)
                self.setFrameOrigin(newOrigin)
                return
            case .upArrow:
                // Behind Menu Bar
                // Calculate menu bar height (top of screen)
                let menuBarHeight = screenFrame.height - visibleFrame.maxY
                if menuBarHeight > 0 {
                    let newFrame = NSRect(x: 0, y: visibleFrame.maxY, width: screenFrame.width, height: menuBarHeight)
                    self.setFrame(newFrame, display: true)
                    // Set level behind menu bar (MainMenuWindow is usually 24, we want just below it)
                    self.level = NSWindow.Level(Int(CGWindowLevelForKey(.mainMenuWindow)) - 1)
                }
                return
            case .downArrow:
                // Behind Dock
                // Calculate dock height (bottom of screen)
                let dockHeight = visibleFrame.minY - screenFrame.minY
                if dockHeight > 0 {
                    let newFrame = NSRect(x: 0, y: screenFrame.minY, width: screenFrame.width, height: dockHeight)
                    self.setFrame(newFrame, display: true)
                    // Set level behind dock (DockWindow is usually 20, we want just below it)
                    self.level = NSWindow.Level(Int(CGWindowLevelForKey(.dockWindow)) - 1)
                }
                return
            default:
                break
            }
            
            // Number keys 1-9
            if let chars = event.characters, let num = Int(chars), num >= 1 && num <= 9 {
                // Resize width to N columns
                let newWidth = CGFloat(num) * CGFloat(Constants.fontSize)
                let newFrame = NSRect(x: self.frame.minX, y: self.frame.minY, width: newWidth, height: self.frame.height)
                self.setFrame(newFrame, display: true)
                return
            }
        }
        
        super.keyDown(with: event)
    }
}
