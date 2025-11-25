import SwiftUI
import Combine
import SpriteKit

struct MatrixView: View {
    var scene: SKScene {
        let scene = MatrixScene()
        scene.scaleMode = .resizeFill
        return scene
    }
    
    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .background(Color.clear)
            .ignoresSafeArea()
    }
}


