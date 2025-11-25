import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        
        context.coordinator.setup(view: mtkView)
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var renderer: MatrixRenderer?
        
        func setup(view: MTKView) {
            renderer = MatrixRenderer(metalKitView: view)
        }
    }
}
