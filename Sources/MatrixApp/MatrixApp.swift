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
        // Default to 1/3 width (approx 5-6 columns depending on screen)
        // or start with 3 columns as per previous logic?
        // Let's stick to the previous logic for initial size: 2/9 of screen width
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
        
        // Chamfered edges
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 15.0
        window.contentView?.layer?.borderWidth = 3.0
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
