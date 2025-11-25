import SpriteKit
import CoreText

class MatrixScene: SKScene {
    var grid: [[SKLabelNode]] = []
    var drops: [Drop] = []
    
    var cols: Int = 0
    var rows: Int = 0
    let fontSize: CGFloat = 16.0
    
    var lastTime: TimeInterval = 0
    
    struct Drop {
        var y: Double
        var speed: Double
        var tailLength: Double
    }
    
    let characters = "abcdefghijklmnopqrstuvwxyz1234567890".map { String($0) }
    
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        view.allowsTransparency = true
        self.anchorPoint = .zero // Bottom-left origin
        
        setupGrid()
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        setupGrid()
    }
    
    func setupGrid() {
        removeAllChildren()
        
        cols = Int(size.width / fontSize)
        rows = Int(size.height / fontSize)
        
        // Safety check
        if cols <= 0 || rows <= 0 { return }
        
        grid = []
        drops = []
        
        // Create nodes
        for c in 0..<cols {
            var colNodes: [SKLabelNode] = []
            for r in 0..<rows {
                let node = SKLabelNode(fontNamed: "Matrix-Code")
                node.fontSize = fontSize
                node.text = characters.randomElement()
                node.fontColor = .green
                node.verticalAlignmentMode = .center
                node.horizontalAlignmentMode = .center
                // Position: x grows right, y grows UP in SpriteKit.
                // We want row 0 at the TOP.
                // So y = height - (r * fontSize) - offset
                let x = CGFloat(c) * fontSize + fontSize/2
                let y = size.height - (CGFloat(r) * fontSize + fontSize/2)
                node.position = CGPoint(x: x, y: y)
                node.alpha = 0 // Start invisible
                
                addChild(node)
                colNodes.append(node)
            }
            grid.append(colNodes)
            
            // Randomize drops
            drops.append(Drop(
                y: Double.random(in: -Double(rows)...0),
                speed: Double.random(in: 2.0...8.0), // Slower speed
                tailLength: Double.random(in: 5...20)
            ))
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        let deltaTime = currentTime - lastTime
        lastTime = currentTime
        
        // Cap delta time to prevent huge jumps
        let dt = min(deltaTime, 0.1)
        
        for c in 0..<cols {
            // Update drop position
            drops[c].y += drops[c].speed * dt
            
            let dropY = drops[c].y
            let tailLength = drops[c].tailLength
            
            // Reset if off screen
            if dropY - tailLength > Double(rows) {
                drops[c].y = Double.random(in: -Double(rows)...0)
                drops[c].speed = Double.random(in: 2.0...8.0)
                drops[c].tailLength = Double.random(in: 5...20)
            }
            
            // Update nodes in this column
            for r in 0..<rows {
                // Logic: drop moves DOWN (increasing index r).
                // But wait, in my logic 'y' is increasing as it falls.
                // 'r' is the row index from TOP (0) to BOTTOM (rows-1).
                // So dropY corresponds to 'r'.
                
                let dist = dropY - Double(r)
                let node = grid[c][r]
                
                if dist >= 0 && dist < tailLength {
                    // Inside tail
                    let brightness = 1.0 - (dist / tailLength)
                    let isHead = (dist < 1.0)
                    
                    node.alpha = brightness
                    
                    if isHead {
                        node.fontColor = .white
                        // node.shadow = ... (SKLabelNode doesn't have simple shadow like SwiftUI)
                    } else {
                        node.fontColor = .green
                    }
                    
                    // Randomly change character
                    if Double.random(in: 0...1) < 0.02 {
                        node.text = characters.randomElement()
                    }
                    
                } else {
                    node.alpha = 0
                }
            }
        }
    }
}
